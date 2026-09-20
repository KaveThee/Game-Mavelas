-- Automatic round lifecycle: all-in pause, timed reveal, and automatic advance.

alter table public.rooms drop constraint if exists rooms_phase_check;
alter table public.rooms add constraint rooms_phase_check check (
  phase in ('lobby', 'selected', 'playing', 'all_answered', 'revealed', 'results', 'closed')
);

create or replace function public.get_public_room_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'room_code', r.code,
    'status', r.status,
    'phase', coalesce(r.phase, r.status),
    'game_mode', r.selected_game,
    'game_title', r.game_title,
    'state_version', r.state_version,
    'round_ends_at', r.round_ends_at,
    'last_transition_at', r.last_transition_at,
    'total_players', (
      select count(*) from public.room_players rp
      where rp.room_id = r.id and rp.role = 'player'
    ),
    'answered_count', (
      select count(*)
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.user_id = pa.player_id
      where pa.round_id = r.current_round_id and rp.role = 'player'
    ),
    'slowest_player_name', case when r.phase = 'all_answered' then (
      select rp.nickname
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.user_id = pa.player_id
      where pa.round_id = r.current_round_id and rp.role = 'player'
      order by pa.answered_at desc, rp.joined_at desc
      limit 1
    ) else null end,
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', rp.nickname,
        'score', rp.score,
        'seat', rp.seat_no,
        'role', rp.role,
        'has_answered', exists(
          select 1 from public.player_answers pa
          where pa.round_id = r.current_round_id and pa.player_id = rp.user_id
        ),
        'is_correct', case when exists(
          select 1 from public.game_rounds gr
          where gr.id = r.current_round_id and gr.status = 'revealed'
        ) then coalesce((
          select pa.is_correct from public.player_answers pa
          where pa.round_id = r.current_round_id and pa.player_id = rp.user_id
        ), false) else null end,
        'points_awarded', case when exists(
          select 1 from public.game_rounds gr
          where gr.id = r.current_round_id and gr.status = 'revealed'
        ) then coalesce((
          select pa.points_awarded from public.player_answers pa
          where pa.round_id = r.current_round_id and pa.player_id = rp.user_id
        ), 0) else null end
      ) order by rp.score desc, rp.joined_at asc)
      from public.room_players rp
      where rp.room_id = r.id and rp.role <> 'spectator'
    ), '[]'::jsonb)
  )
  from public.rooms r
  where r.code = upper(trim(p_room_code));
$$;

create or replace function public.auto_reveal_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room record;
  v_round record;
begin
  if v_user is null or not exists (
    select 1 from public.room_players
    where room_id = p_room_id and user_id = v_user
  ) then
    raise exception 'You are not in this room';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'Room not found'; end if;
  if v_room.phase = 'revealed' then
    return jsonb_build_object('revealed', true, 'already_revealed', true);
  end if;
  if v_room.status <> 'playing' then raise exception 'Game is not active'; end if;

  select gr.*, q.game_mode into v_round
  from public.game_rounds gr
  join public.questions q on q.id = gr.question_id
  where gr.room_id = p_room_id and gr.status = 'open'
  order by gr.position
  limit 1
  for update of gr;

  if not found then raise exception 'Round is no longer open'; end if;

  if not (
    (v_room.phase = 'all_answered' and v_room.last_transition_at <= now() - interval '3 seconds')
    or (v_room.phase = 'playing' and v_round.closes_at <= now())
  ) then
    raise exception 'Reveal is not ready';
  end if;

  update public.game_rounds
  set status = 'revealed', closes_at = least(coalesce(closes_at, now()), now())
  where id = v_round.id;

  update public.room_players rp
  set score = rp.score + pa.points_awarded
  from public.player_answers pa
  where pa.round_id = v_round.id
    and pa.player_id = rp.user_id
    and pa.room_id = rp.room_id
    and pa.is_correct;

  if v_round.game_mode = 'guess_image' then
    update public.clue_heist_rounds
    set turn_phase = 'revealed', updated_at = now()
    where round_id = v_round.id;
  end if;

  update public.rooms
  set phase = 'revealed',
      round_ends_at = null,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object('revealed', true, 'round_id', v_round.id);
end;
$$;

create or replace function public.auto_advance_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room record;
  v_next_round record;
  v_closes_at timestamptz;
begin
  if v_user is null or not exists (
    select 1 from public.room_players
    where room_id = p_room_id and user_id = v_user
  ) then
    raise exception 'You are not in this room';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'Room not found'; end if;
  if v_room.status = 'results' then
    return jsonb_build_object('finished', true, 'already_finished', true);
  end if;
  if v_room.status <> 'playing' or v_room.phase <> 'revealed'
     or v_room.last_transition_at > now() - interval '6 seconds' then
    raise exception 'Next round is not ready';
  end if;

  update public.game_rounds
  set status = 'closed', closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('open', 'revealed');

  select gr.id, gr.position, q.duration_seconds into v_next_round
  from public.game_rounds gr
  join public.questions q on q.id = gr.question_id
  where gr.room_id = p_room_id and gr.status = 'pending'
  order by gr.position
  limit 1;

  if v_next_round.id is null then
    update public.rooms
    set status = 'results', phase = 'results', current_round_id = null,
        round_ends_at = null, state_version = state_version + 1,
        last_transition_at = now(), updated_at = now()
    where id = p_room_id;
    return jsonb_build_object('finished', true);
  end if;

  v_closes_at := now() + (coalesce(v_next_round.duration_seconds, 20) || ' seconds')::interval;

  update public.game_rounds
  set status = 'open', opens_at = now(), closes_at = v_closes_at
  where id = v_next_round.id;

  update public.rooms
  set phase = 'playing', current_round_id = v_next_round.id,
      round_ends_at = v_closes_at, state_version = state_version + 1,
      last_transition_at = now(), updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'finished', false,
    'round_id', v_next_round.id,
    'position', v_next_round.position,
    'closes_at', v_closes_at
  );
end;
$$;

create or replace function public.submit_who_am_i_guess(p_round_id uuid, p_guess text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_round record;
  v_correct_text text;
  v_is_correct boolean;
  v_points integer := 0;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if char_length(trim(coalesce(p_guess, ''))) < 2 then raise exception 'Enter a fuller guess'; end if;

  select gr.*, q.game_mode, q.base_points into v_round
  from public.game_rounds gr
  join public.questions q on q.id = gr.question_id
  where gr.id = p_round_id;

  if not found or v_round.game_mode <> 'who_am_i' then raise exception 'This is not a Who Am I round'; end if;
  if v_round.status <> 'open' then raise exception 'This round is closed'; end if;
  if v_round.active_player_id <> v_user then raise exception 'Only the active player can submit this guess'; end if;
  if exists (select 1 from public.player_answers where round_id = p_round_id and player_id = v_user) then
    raise exception 'Your final guess is already locked in';
  end if;

  select option_text into v_correct_text
  from public.question_options
  where question_id = v_round.question_id and is_correct = true
  limit 1;

  v_is_correct := regexp_replace(lower(trim(p_guess)), '[^a-z0-9]+', '', 'g')
    = regexp_replace(lower(v_correct_text), '[^a-z0-9]+', '', 'g');
  if v_is_correct then v_points := v_round.base_points; end if;

  insert into public.player_answers
    (round_id, room_id, player_id, free_text_answer, is_correct, points_awarded)
  values
    (p_round_id, v_round.room_id, v_user, trim(p_guess), v_is_correct, v_points);

  if v_is_correct then
    update public.room_players
    set score = score + v_points
    where room_id = v_round.room_id and user_id = v_user;
  end if;

  update public.game_rounds
  set status = 'revealed', closes_at = now()
  where id = p_round_id;

  update public.rooms
  set phase = 'revealed', round_ends_at = null,
      state_version = state_version + 1,
      last_transition_at = now(), updated_at = now()
  where id = v_round.room_id;

  return jsonb_build_object('correct', v_is_correct, 'points_awarded', v_points);
end;
$$;

revoke all on function public.auto_reveal_round(uuid) from public, anon;
revoke all on function public.auto_advance_round(uuid) from public, anon;
revoke all on function public.submit_who_am_i_guess(uuid, text) from public, anon;
grant execute on function public.auto_reveal_round(uuid) to authenticated;
grant execute on function public.auto_advance_round(uuid) to authenticated;
grant execute on function public.submit_who_am_i_guess(uuid, text) to authenticated;
revoke all on function public.get_public_room_state(text) from public, anon;
grant execute on function public.get_public_room_state(text) to authenticated;
