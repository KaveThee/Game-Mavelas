-- The host is also a participant. Count hosts and players consistently so a
-- solo host, or the last person in a multiplayer room, triggers early reveal.

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
  v_participant_count integer;
  v_answer_count integer;
  v_all_answered boolean := false;
begin
  if v_user is null then raise exception 'Sign in before answering'; end if;

  select * into v_round
  from public.game_rounds
  where id = p_round_id
  for update;

  if not found then raise exception 'Round not found'; end if;
  if v_round.status <> 'open' then raise exception 'This round is not currently accepting answers'; end if;
  if v_round.closes_at is not null and now() > (v_round.closes_at + interval '2 seconds') then
    raise exception 'Time is up for this question';
  end if;

  if not exists (
    select 1 from public.room_players rp
    where rp.room_id = v_round.room_id
      and rp.user_id = v_user
      and rp.role in ('host', 'player')
  ) then
    raise exception 'You are not in this room';
  end if;

  if exists (
    select 1 from public.player_answers
    where round_id = p_round_id and player_id = v_user
  ) then
    raise exception 'You have already locked in your answer for this round';
  end if;

  select qo.is_correct into v_correct
  from public.question_options qo
  where qo.id = p_option_id and qo.question_id = v_round.question_id;
  if v_correct is null then raise exception 'Selected option is invalid for this question'; end if;

  select case when v_correct then coalesce(q.base_points, 100) else 0 end
  into v_points
  from public.questions q
  where q.id = v_round.question_id;

  insert into public.player_answers
    (round_id, room_id, player_id, selected_option_id, is_correct, points_awarded, answered_at)
  values
    (v_round.id, v_round.room_id, v_user, p_option_id, v_correct, v_points, now());

  select count(*) into v_participant_count
  from public.room_players
  where room_id = v_round.room_id and role in ('host', 'player');

  select count(*) into v_answer_count
  from public.player_answers pa
  join public.room_players rp
    on rp.room_id = pa.room_id and rp.user_id = pa.player_id
  where pa.round_id = v_round.id and rp.role in ('host', 'player');

  v_all_answered := v_participant_count > 0 and v_answer_count >= v_participant_count;

  if v_all_answered then
    update public.game_rounds
    set closes_at = now()
    where id = v_round.id;

    update public.rooms
    set phase = 'all_answered',
        round_ends_at = null,
        state_version = state_version + 1,
        last_transition_at = now(),
        updated_at = now()
    where id = v_round.room_id and phase = 'playing';
  else
    update public.rooms
    set state_version = state_version + 1, updated_at = now()
    where id = v_round.room_id;
  end if;

  return jsonb_build_object(
    'accepted', true,
    'has_answered', true,
    'answered_count', v_answer_count,
    'participant_count', v_participant_count,
    'all_answered', v_all_answered
  );
end;
$$;

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
      where rp.room_id = r.id and rp.role in ('host', 'player')
    ),
    'answered_count', (
      select count(*)
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.user_id = pa.player_id
      where pa.round_id = r.current_round_id and rp.role in ('host', 'player')
    ),
    'slowest_player_name', case when r.phase = 'all_answered' then (
      select rp.nickname
      from public.player_answers pa
      join public.room_players rp
        on rp.room_id = pa.room_id and rp.user_id = pa.player_id
      where pa.round_id = r.current_round_id and rp.role in ('host', 'player')
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
      where rp.room_id = r.id and rp.role in ('host', 'player')
    ), '[]'::jsonb)
  )
  from public.rooms r
  where r.code = upper(trim(p_room_code));
$$;

revoke all on function public.submit_game_answer(uuid, uuid) from public, anon;
grant execute on function public.submit_game_answer(uuid, uuid) to authenticated;
revoke all on function public.get_public_room_state(text) from public, anon;
grant execute on function public.get_public_room_state(text) to authenticated;
