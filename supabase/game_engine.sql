-- Secure game engine. Run after game_content.sql and seed_content.sql.
-- Functions deliberately expose prompts/options, never answer keys.

drop policy if exists "room members read answers" on public.player_answers;
drop policy if exists "players read own answers" on public.player_answers;
create policy "players read own answers" on public.player_answers for select to authenticated
  using (player_id = (select auth.uid()));

create or replace function public.start_game(p_room_id uuid, p_template_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_template public.round_templates%rowtype;
  v_step public.round_template_steps%rowtype;
  v_question public.questions%rowtype;
  v_position smallint := 0;
  v_total integer := 0;
begin
  if v_user is null then raise exception 'Sign in before starting a game'; end if;
  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status = 'lobby'
  ) then raise exception 'Only the room host can start this lobby'; end if;

  select * into v_template from public.round_templates
  where code = p_template_code and is_active = true;
  if not found then raise exception 'That game template is unavailable'; end if;

  delete from public.game_rounds where room_id = p_room_id;
  for v_step in
    select * from public.round_template_steps where template_id = v_template.id order by position
  loop
    for v_question in
      select q.* from public.questions q
      where q.status = 'approved'
        and q.game_mode = v_template.game_mode
        and q.difficulty between v_step.difficulty_min and v_step.difficulty_max
        and (v_step.category_id is null or q.category_id = v_step.category_id)
      order by random()
      limit v_step.question_count
    loop
      v_position := v_position + 1;
      insert into public.game_rounds (room_id, template_id, question_id, position, status, opens_at)
      values (p_room_id, v_template.id, v_question.id, v_position,
        case when v_position = 1 then 'open' else 'pending' end,
        case when v_position = 1 then now() else null end);
      v_total := v_total + 1;
    end loop;
  end loop;

  if v_total = 0 then raise exception 'No approved questions match this template yet'; end if;

  update public.rooms
  set selected_game = v_template.game_mode,
      status = 'playing',
      state = jsonb_build_object('template_code', v_template.code, 'round_count', v_total),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object('room_id', p_room_id, 'round_count', v_total, 'game_mode', v_template.game_mode);
end;
$$;

create or replace function public.current_game_question(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_payload jsonb;
begin
  if v_user is null then raise exception 'Sign in before playing'; end if;
  if not exists (
    select 1 from public.room_players rp where rp.room_id = p_room_id and rp.user_id = v_user
  ) then raise exception 'You are not in this room'; end if;

  select jsonb_build_object(
    'round_id', gr.id,
    'position', gr.position,
    'prompt', q.prompt,
    'explanation', q.explanation,
    'game_mode', q.game_mode,
    'duration_seconds', q.duration_seconds,
    'base_points', q.base_points,
    'media', case when m.id is null then null else jsonb_build_object('type', m.asset_type, 'url', m.public_url, 'alt', m.alt_text) end,
    'options', coalesce((
      select jsonb_agg(jsonb_build_object('id', qo.id, 'text', qo.option_text) order by qo.position)
      from public.question_options qo where qo.question_id = q.id
    ), '[]'::jsonb)
  ) into v_payload
  from public.game_rounds gr
  join public.questions q on q.id = gr.question_id
  left join public.media_assets m on m.id = q.media_id
  where gr.room_id = p_room_id and gr.status = 'open'
  order by gr.position
  limit 1;

  return v_payload;
end;
$$;

create or replace function public.submit_game_answer(p_round_id uuid, p_option_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_round public.game_rounds%rowtype;
  v_correct boolean;
  v_points integer := 0;
begin
  if v_user is null then raise exception 'Sign in before answering'; end if;
  select * into v_round from public.game_rounds where id = p_round_id and status = 'open';
  if not found then raise exception 'This round is no longer open'; end if;
  if not exists (select 1 from public.room_players rp where rp.room_id = v_round.room_id and rp.user_id = v_user) then
    raise exception 'You are not in this room';
  end if;

  select qo.is_correct into v_correct from public.question_options qo
  where qo.id = p_option_id and qo.question_id = v_round.question_id;
  if v_correct is null then raise exception 'That option does not belong to this question'; end if;

  select case when v_correct then q.base_points else 0 end into v_points
  from public.questions q where q.id = v_round.question_id;

  insert into public.player_answers (round_id, room_id, player_id, selected_option_id, is_correct, points_awarded)
  values (v_round.id, v_round.room_id, v_user, p_option_id, v_correct, v_points)
  on conflict (round_id, player_id) do nothing;
  if not found then raise exception 'You have already answered this round'; end if;

  update public.room_players
  set score = score + v_points
  where room_id = v_round.room_id and user_id = v_user;

  return jsonb_build_object('accepted', true, 'is_correct', v_correct, 'points_awarded', v_points);
end;
$$;

create or replace function public.advance_game_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_next_id uuid;
begin
  if v_user is null then raise exception 'Sign in before advancing a game'; end if;
  if not exists (select 1 from public.rooms r where r.id = p_room_id and r.host_id = v_user and r.status = 'playing') then
    raise exception 'Only the room host can advance this game';
  end if;

  update public.game_rounds set status = 'revealed', closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status = 'open';

  select id into v_next_id from public.game_rounds
  where room_id = p_room_id and status = 'pending'
  order by position limit 1;

  if v_next_id is null then
    update public.rooms set status = 'results', updated_at = now() where id = p_room_id;
    return jsonb_build_object('finished', true);
  end if;

  update public.game_rounds set status = 'open', opens_at = now() where id = v_next_id;
  return jsonb_build_object('finished', false, 'round_id', v_next_id);
end;
$$;

revoke all on function public.start_game(uuid, text) from public, anon;
revoke all on function public.current_game_question(uuid) from public, anon;
revoke all on function public.submit_game_answer(uuid, uuid) from public, anon;
revoke all on function public.advance_game_round(uuid) from public, anon;
grant execute on function public.start_game(uuid, text) to authenticated;
grant execute on function public.current_game_question(uuid) to authenticated;
grant execute on function public.submit_game_answer(uuid, uuid) to authenticated;
grant execute on function public.advance_game_round(uuid) to authenticated;
