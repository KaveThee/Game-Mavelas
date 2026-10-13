-- Room lifecycle controls for explicit participant departure and host-driven
-- session termination. Both operations lock the room row so host transfer,
-- answer quorum repair, and game teardown happen atomically.

create or replace function public.leave_game_room(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_room public.rooms%rowtype;
  v_player public.room_players%rowtype;
  v_successor uuid;
  v_turn_successor uuid;
  v_remaining_players integer;
  v_answer_count integer;
  v_was_host boolean;
begin
  if v_user is null then
    raise exception 'Sign in before leaving a room';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  select * into v_player
  from public.room_players
  where room_id = p_room_id
    and user_id = v_user
    and role in ('host', 'player')
  for update;

  if not found then
    raise exception 'You are not an active player in this room';
  end if;

  v_was_host := v_room.host_id = v_user or v_player.role = 'host';

  -- The next joined active participant owns any turn abandoned by the leaver.
  -- Prefer the next seat chronologically, then wrap to the earliest participant.
  select rp.user_id into v_turn_successor
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.user_id <> v_user
    and rp.role in ('host', 'player')
  order by
    case when rp.joined_at > v_player.joined_at then 0 else 1 end,
    rp.joined_at,
    rp.user_id
  limit 1;

  delete from public.player_answers
  where room_id = p_room_id and player_id = v_user;

  update public.game_rounds
  set active_player_id = v_turn_successor
  where room_id = p_room_id
    and active_player_id = v_user
    and status in ('pending', 'open', 'revealed');

  -- Trivia Dash participant state is removed by its room-player foreign keys.
  delete from public.room_players
  where room_id = p_room_id and user_id = v_user;

  select count(*) into v_remaining_players
  from public.room_players rp
  where rp.room_id = p_room_id and rp.role in ('host', 'player');

  if v_remaining_players = 0 then
    update public.game_rounds
    set status = 'closed', closes_at = coalesce(closes_at, now())
    where room_id = p_room_id and status in ('pending', 'open', 'revealed');

    update public.rooms
    set status = 'closed',
        phase = 'closed',
        current_round_id = null,
        round_ends_at = null,
        state = coalesce(state, '{}'::jsonb) || jsonb_build_object(
          'closed_reason', 'last_player_left',
          'closed_at', now()
        ),
        state_version = state_version + 1,
        last_transition_at = now(),
        updated_at = now()
    where id = p_room_id;

    return jsonb_build_object(
      'left', true,
      'was_host', v_was_host,
      'room_closed', true,
      'new_host_id', null
    );
  end if;

  if v_was_host then
    -- Host rights pass to the earliest remaining participant: normally the
    -- second person who joined the room. UUID is a deterministic tie-breaker.
    select rp.user_id into v_successor
    from public.room_players rp
    where rp.room_id = p_room_id and rp.role in ('host', 'player')
    order by rp.joined_at, rp.user_id
    limit 1;

    update public.room_players
    set role = case when user_id = v_successor then 'host' else 'player' end
    where room_id = p_room_id and role in ('host', 'player');

    update public.rooms
    set host_id = v_successor,
        state = coalesce(state, '{}'::jsonb) || jsonb_build_object(
          'host_transferred_at', now()
        ),
        state_version = state_version + 1,
        last_transition_at = now(),
        updated_at = now()
    where id = p_room_id;
  else
    update public.rooms
    set state_version = state_version + 1,
        last_transition_at = now(),
        updated_at = now()
    where id = p_room_id;
  end if;

  -- If the departing player was the only unanswered participant, allow the
  -- normal reveal clock to proceed instead of leaving the round stranded.
  if v_room.status = 'playing'
     and v_room.phase = 'playing'
     and v_room.current_round_id is not null then
    select count(*) into v_answer_count
    from public.player_answers pa
    join public.room_players rp
      on rp.room_id = pa.room_id and rp.user_id = pa.player_id
    where pa.round_id = v_room.current_round_id
      and rp.role in ('host', 'player');

    if v_answer_count >= v_remaining_players then
      update public.game_rounds
      set closes_at = least(coalesce(closes_at, now()), now())
      where id = v_room.current_round_id and status = 'open';

      update public.rooms
      set phase = 'all_answered',
          round_ends_at = now(),
          state_version = state_version + 1,
          last_transition_at = now(),
          updated_at = now()
      where id = p_room_id and status = 'playing' and phase = 'playing';
    end if;
  end if;

  return jsonb_build_object(
    'left', true,
    'was_host', v_was_host,
    'room_closed', false,
    'new_host_id', case when v_was_host then v_successor else v_room.host_id end
  );
end;
$$;

create or replace function public.host_end_game(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_room public.rooms%rowtype;
  v_template_code text;
  v_selection text;
  v_signal uuid := gen_random_uuid();
begin
  if v_user is null then
    raise exception 'Sign in before ending a game';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'Room not found'; end if;
  if v_room.host_id <> v_user then
    raise exception 'Only the room host can end the game';
  end if;
  if v_room.status = 'closed' then
    raise exception 'This room is closed';
  end if;

  select rt.code into v_template_code
  from public.game_rounds gr
  join public.round_templates rt on rt.id = gr.template_id
  where gr.room_id = p_room_id
  order by gr.position
  limit 1;

  v_selection := case
    when v_room.selected_game in ('trivia_dash', 'trivia-dash') then 'trivia-dash'
    when v_template_code = 'trivia_vault_kenya' then 'trivia-kenya'
    when v_template_code = 'trivia_vault_scitech' then 'trivia-scitech'
    when v_template_code = 'trivia_vault_mix' then 'trivia-mix'
    when v_template_code = 'flag_frenzy_africa' then 'flags'
    when v_template_code = 'who_am_i_kenya' then 'who'
    when v_template_code = 'clue_heist_classic' then 'image'
    when v_template_code = 'logo_rush_world' then 'logos'
    when v_room.selected_game in ('trivia-kenya', 'trivia-scitech', 'trivia-mix', 'flags', 'who', 'image', 'logos')
      then v_room.selected_game
    else 'trivia-kenya'
  end;

  update public.game_rounds
  set status = 'closed', closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('pending', 'open', 'revealed');

  delete from public.player_answers where room_id = p_room_id;
  delete from public.trivia_dash_player_state where room_id = p_room_id;
  update public.room_players set score = 0 where room_id = p_room_id;

  update public.rooms
  set status = 'lobby',
      phase = 'lobby',
      selected_game = v_selection,
      game_title = null,
      current_round_id = null,
      round_ends_at = null,
      state = coalesce(state, '{}'::jsonb) || jsonb_build_object(
        'end_game_signal', v_signal,
        'ended_at', now(),
        'ended_game', v_room.selected_game
      ),
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'ended', true,
    'selected_game', v_selection,
    'end_game_signal', v_signal
  );
end;
$$;

-- The display consumes this opaque signal only to return to the public menu.
-- No private room state or participant identity is exposed.
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
    'end_game_signal', r.state ->> 'end_game_signal',
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

revoke all on function public.leave_game_room(uuid) from public, anon;
revoke all on function public.host_end_game(uuid) from public, anon;
revoke all on function public.get_public_room_state(text) from public, anon;

grant execute on function public.leave_game_room(uuid) to authenticated;
grant execute on function public.host_end_game(uuid) to authenticated;
grant execute on function public.get_public_room_state(text) to authenticated;
