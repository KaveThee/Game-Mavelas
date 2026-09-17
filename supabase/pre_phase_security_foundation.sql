-- Pre-Phase security foundation for Game Mavelas.
-- Apply after schema.sql, shared_screen_core.sql, and phase3_game_engine.sql.
-- This migration makes room creation/joining atomic and removes direct client
-- mutation of player scores, roles, and membership ownership.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.room_players rp
      where rp.room_id = p_room_id
        and rp.user_id = (select auth.uid())
    );
$$;

revoke all on function private.is_room_member(uuid) from public, anon;
grant execute on function private.is_room_member(uuid) to authenticated;

-- Remove broad policies and all direct room/player inserts or player updates.
drop policy if exists "players can read rooms" on public.rooms;
drop policy if exists "players can create rooms" on public.rooms;
drop policy if exists "players can read room members" on public.room_players;
drop policy if exists "players join rooms as themselves" on public.room_players;
drop policy if exists "players update their own score" on public.room_players;

create policy "room members read their rooms"
on public.rooms
for select
to authenticated
using ((select private.is_room_member(id)));

create policy "room members read fellow members"
on public.room_players
for select
to authenticated
using ((select private.is_room_member(room_id)));

revoke insert on public.rooms from anon, authenticated;
revoke insert, update, delete on public.room_players from anon, authenticated;

create or replace function public.create_game_room(
  p_nickname text,
  p_selected_game text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_nickname text := btrim(p_nickname);
  v_game text := lower(btrim(p_selected_game));
  v_code text;
  v_room public.rooms%rowtype;
  v_attempt smallint := 0;
begin
  if v_user is null then
    raise exception 'Sign in before creating a room';
  end if;

  if char_length(v_nickname) not between 2 and 24 then
    raise exception 'Nickname must be between 2 and 24 characters';
  end if;

  if v_game not in ('trivia', 'flags', 'flag_frenzy', 'who', 'who_am_i', 'image', 'guess_image') then
    raise exception 'Unsupported game selection';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text || v_user::text), 1, 6));

    begin
      insert into public.rooms (
        code,
        host_id,
        selected_game,
        status,
        phase
      )
      values (
        v_code,
        v_user,
        v_game,
        'lobby',
        'lobby'
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

  insert into public.room_players (
    room_id,
    user_id,
    nickname,
    role
  )
  values (
    v_room.id,
    v_user,
    v_nickname,
    'host'
  );

  return jsonb_build_object(
    'id', v_room.id,
    'code', v_room.code,
    'status', v_room.status,
    'host_id', v_room.host_id,
    'selected_game', v_room.selected_game
  );
end;
$$;

revoke all on function public.create_game_room(text, text) from public, anon;
grant execute on function public.create_game_room(text, text) to authenticated;

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
  v_player_count integer;
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

  select *
  into v_room
  from public.rooms
  where code = v_code
  for update;

  if not found then
    raise exception 'Room not found. Check the code and try again';
  end if;

  if v_room.status = 'closed' then
    raise exception 'This room is closed';
  end if;

  select rp.role
  into v_existing_role
  from public.room_players rp
  where rp.room_id = v_room.id
    and rp.user_id = v_user;

  if v_existing_role is null then
    select count(*)
    into v_player_count
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.role <> 'spectator';

    if v_player_count >= v_room.max_players then
      raise exception 'This room is full';
    end if;

    insert into public.room_players (
      room_id,
      user_id,
      nickname,
      role
    )
    values (
      v_room.id,
      v_user,
      v_nickname,
      'player'
    );
  else
    -- Preserve host/moderator authority; rejoining can only refresh the nickname.
    update public.room_players
    set nickname = v_nickname,
        is_connected = true,
        last_seen_at = now()
    where room_id = v_room.id
      and user_id = v_user;
  end if;

  return jsonb_build_object(
    'id', v_room.id,
    'code', v_room.code,
    'status', v_room.status,
    'host_id', v_room.host_id,
    'selected_game', v_room.selected_game,
    'role', coalesce(v_existing_role, 'player')
  );
end;
$$;

revoke all on function public.join_game_room(text, text) from public, anon;
grant execute on function public.join_game_room(text, text) to authenticated;

-- Remove default PUBLIC/anon execution from the existing privileged game API.
-- Only the deliberately exposed, internally-authorized functions remain callable
-- by authenticated anonymous-player sessions.
revoke all on function public.start_game(uuid, text) from public, anon;
revoke all on function public.submit_game_answer(uuid, uuid) from public, anon;
revoke all on function public.host_reveal_round(uuid) from public, anon;
revoke all on function public.host_advance_round(uuid) from public, anon;
revoke all on function public.host_end_game(uuid) from public, anon;
revoke all on function public.get_player_game_state(uuid) from public, anon;
revoke all on function public.get_public_room_state(text) from public, anon;
revoke all on function public.get_public_round_state(text) from public, anon;

grant execute on function public.start_game(uuid, text) to authenticated;
grant execute on function public.submit_game_answer(uuid, uuid) to authenticated;
grant execute on function public.host_reveal_round(uuid) to authenticated;
grant execute on function public.host_advance_round(uuid) to authenticated;
grant execute on function public.host_end_game(uuid) to authenticated;
grant execute on function public.get_player_game_state(uuid) to authenticated;
grant execute on function public.get_public_room_state(text) to authenticated;
grant execute on function public.get_public_round_state(text) to authenticated;

-- Superseded/internal functions must not remain callable through the Data API.
revoke all on function public.advance_game_round(uuid) from public, anon, authenticated;
revoke all on function public.current_game_question(uuid) from public, anon, authenticated;
revoke all on function public.assign_who_am_i_player() from public, anon, authenticated;
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

-- Host room updates stay protected by the existing host-only UPDATE policy.
-- Scores and roles are now mutable only through vetted SECURITY DEFINER RPCs.
