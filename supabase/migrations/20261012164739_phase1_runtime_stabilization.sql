-- Phase 1 runtime stabilization (hosted ledger version 20261012164739).
--
-- This migration intentionally does not enable any new game. It tightens the
-- shared room lifecycle used by the existing games and by future modules.

create or replace function private.normalize_room_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'lobby' and new.phase not in ('lobby', 'selected') then
    new.phase := 'lobby';
  elsif new.status = 'playing' and new.phase not in ('playing', 'all_answered', 'revealed') then
    new.phase := 'playing';
  elsif new.status = 'results' then
    new.phase := 'results';
    new.current_round_id := null;
    new.round_ends_at := null;
  elsif new.status = 'closed' then
    new.phase := 'closed';
    new.current_round_id := null;
    new.round_ends_at := null;
  end if;

  return new;
end;
$$;

revoke all on function private.normalize_room_lifecycle() from public, anon, authenticated;

drop trigger if exists normalize_room_lifecycle_before_write on public.rooms;
create trigger normalize_room_lifecycle_before_write
before insert or update of status, phase on public.rooms
for each row execute function private.normalize_room_lifecycle();

-- Repair legacy/test rooms that already contain impossible status/phase pairs.
update public.rooms
set phase = case status
  when 'lobby' then 'lobby'
  when 'playing' then 'playing'
  when 'results' then 'results'
  when 'closed' then 'closed'
  else phase
end,
current_round_id = case when status in ('results', 'closed') then null else current_round_id end,
round_ends_at = case when status in ('results', 'closed') then null else round_ends_at end,
updated_at = now()
where (status = 'lobby' and phase not in ('lobby', 'selected'))
   or (status = 'playing' and phase not in ('playing', 'all_answered', 'revealed'))
   or (status = 'results' and phase <> 'results')
   or (status = 'closed' and phase <> 'closed');

create or replace function public.create_display_room()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display_user uuid := (select auth.uid());
  v_code text;
  v_room public.rooms%rowtype;
  v_attempt smallint := 0;
begin
  if v_display_user is null then
    raise exception 'Sign in before opening a display room';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text || v_display_user::text), 1, 6));

    begin
      insert into public.rooms (code, host_id, selected_game, status, phase, state)
      values (
        v_code,
        v_display_user,
        'trivia-kenya',
        'lobby',
        'lobby',
        jsonb_build_object('display_first', true, 'awaiting_host', true)
      )
      returning * into v_room;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 10 then
          raise exception 'Could not allocate a unique room code';
        end if;
    end;
  end loop;

  -- The display is a room member for RLS-protected subscriptions and as a
  -- non-scoring lifecycle fallback. It is never counted as a player.
  insert into public.room_players (room_id, user_id, nickname, role)
  values (v_room.id, v_display_user, 'Shared display', 'spectator');

  return jsonb_build_object(
    'id', v_room.id,
    'code', v_room.code,
    'status', v_room.status,
    'awaiting_host', true
  );
end;
$$;

revoke all on function public.create_display_room() from public, anon;
grant execute on function public.create_display_room() to authenticated;

create or replace function public.join_game_room(
  p_room_code text,
  p_nickname text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_code text := upper(btrim(p_room_code));
  v_nickname text := btrim(p_nickname);
  v_room public.rooms%rowtype;
  v_existing_role text;
  v_assigned_role text;
  v_player_count integer;
  v_display_first boolean;
begin
  if v_user is null then
    raise exception 'Sign in before joining a room';
  end if;

  if char_length(v_code) not between 4 and 6 or v_code !~ '^[A-Z0-9]+$' then
    raise exception 'Enter a valid room code';
  end if;

  if char_length(v_nickname) not between 2 and 24 then
    raise exception 'Nickname must be between 2 and 24 characters';
  end if;

  select * into v_room
  from public.rooms
  where code = v_code
  for update;

  if not found then
    raise exception 'Room not found. Check the code and try again';
  end if;

  select rp.role into v_existing_role
  from public.room_players rp
  where rp.room_id = v_room.id and rp.user_id = v_user;

  if v_room.status = 'closed' then
    raise exception 'This room is closed';
  end if;

  -- Existing participants may always reconnect. New identities can enter only
  -- before play starts, preventing mid-round answer-count and board-state drift.
  if v_existing_role is null
     and (v_room.status <> 'lobby' or v_room.phase not in ('lobby', 'selected')) then
    raise exception 'This game has already started. Join the next game from the lobby';
  end if;

  if v_existing_role is not null then
    update public.room_players
    set nickname = case when v_existing_role = 'spectator' then nickname else v_nickname end,
        is_connected = true,
        last_seen_at = now()
    where room_id = v_room.id and user_id = v_user;
    v_assigned_role := v_existing_role;
  else
    select count(*) into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id and rp.role <> 'spectator';

    if v_player_count >= v_room.max_players then
      raise exception 'This room is full';
    end if;

    v_display_first :=
      coalesce((v_room.state ->> 'display_first')::boolean, false)
      and coalesce((v_room.state ->> 'awaiting_host')::boolean, false)
      and not exists (
        select 1 from public.room_players rp
        where rp.room_id = v_room.id and rp.role = 'host'
      );

    if v_display_first then
      v_assigned_role := 'host';
      update public.rooms
      set host_id = v_user,
          state = (coalesce(state, '{}'::jsonb) - 'awaiting_host')
            || jsonb_build_object(
              'display_first', true,
              'awaiting_host', false,
              'host_claimed_at', now()
            ),
          state_version = state_version + 1,
          last_transition_at = now(),
          updated_at = now()
      where id = v_room.id;
    else
      v_assigned_role := 'player';
    end if;

    insert into public.room_players (room_id, user_id, nickname, role)
    values (v_room.id, v_user, v_nickname, v_assigned_role);
  end if;

  return jsonb_build_object(
    'id', v_room.id,
    'code', v_room.code,
    'status', v_room.status,
    'host_id', case
      when v_assigned_role = 'host' then v_user
      else (select r.host_id from public.rooms r where r.id = v_room.id)
    end,
    'selected_game', v_room.selected_game,
    'role', v_assigned_role
  );
end;
$$;

revoke all on function public.join_game_room(text, text) from public, anon;
grant execute on function public.join_game_room(text, text) to authenticated;
