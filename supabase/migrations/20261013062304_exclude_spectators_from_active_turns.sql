-- Phase 2 production audit: a display is a lifecycle spectator, never a
-- playable turn owner. Keep Who Am I and Clue Heist turns on phone users.

create or replace function public.assign_who_am_i_player()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if new.active_player_id is not null then return new; end if;

  if exists (
    select 1 from public.questions q
    where q.id = new.question_id and q.game_mode = 'who_am_i'
  ) then
    select count(*) into v_count
    from public.room_players
    where room_id = new.room_id and role in ('host', 'player');

    if v_count = 0 then raise exception 'Who Am I needs at least one controller'; end if;

    select rp.user_id into new.active_player_id
    from public.room_players rp
    where rp.room_id = new.room_id and rp.role in ('host', 'player')
    order by rp.joined_at, rp.user_id
    offset ((new.position - 1) % v_count)
    limit 1;
  end if;
  return new;
end;
$$;

create or replace function public.setup_clue_heist_round()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if exists (
    select 1 from public.questions q
    where q.id = new.question_id and q.game_mode = 'guess_image'
  ) then
    select count(*) into v_count
    from public.room_players
    where room_id = new.room_id and role in ('host', 'player');

    if v_count = 0 then raise exception 'Clue Heist needs at least one controller'; end if;

    if new.active_player_id is null then
      select rp.user_id into new.active_player_id
      from public.room_players rp
      where rp.room_id = new.room_id and rp.role in ('host', 'player')
      order by rp.joined_at, rp.user_id
      offset ((new.position - 1) % v_count)
      limit 1;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.assign_who_am_i_player() from public, anon, authenticated;
revoke all on function public.setup_clue_heist_round() from public, anon, authenticated;

-- Repair any currently open special-mode round that was assigned to a display.
update public.game_rounds gr
set active_player_id = (
  select rp.user_id
  from public.room_players rp
  where rp.room_id = gr.room_id and rp.role in ('host', 'player')
  order by rp.joined_at, rp.user_id
  limit 1
)
from public.questions q
where q.id = gr.question_id
  and q.game_mode in ('who_am_i', 'guess_image')
  and gr.status in ('pending', 'open')
  and not exists (
    select 1 from public.room_players active_player
    where active_player.room_id = gr.room_id
      and active_player.user_id = gr.active_player_id
      and active_player.role in ('host', 'player')
  );

-- Defense in depth: interactive answer rows can only originate from a phone
-- controller role, even if a future RPC forgets to repeat this check.
create or replace function private.require_round_interactive_player()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
  v_user uuid := (select auth.uid());
begin
  select gr.room_id into v_room_id
  from public.game_rounds gr
  where gr.id = new.round_id;

  if v_user is null or not exists (
    select 1 from public.room_players rp
    where rp.room_id = v_room_id
      and rp.user_id = v_user
      and rp.role in ('host', 'player')
  ) then
    raise exception 'Only a player controller can take this action';
  end if;

  return new;
end;
$$;

create or replace function private.require_room_interactive_player()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null or not exists (
    select 1 from public.room_players rp
    where rp.room_id = new.room_id
      and rp.user_id = v_user
      and rp.role in ('host', 'player')
  ) then
    raise exception 'Only a player controller can take this action';
  end if;

  return new;
end;
$$;

revoke all on function private.require_round_interactive_player() from public, anon, authenticated;
revoke all on function private.require_room_interactive_player() from public, anon, authenticated;

drop trigger if exists require_interactive_player_on_answers on public.player_answers;
create trigger require_interactive_player_on_answers
before insert on public.player_answers
for each row execute function private.require_round_interactive_player();

drop trigger if exists require_interactive_player_on_who_clues on public.who_am_i_clues;
create trigger require_interactive_player_on_who_clues
before insert on public.who_am_i_clues
for each row execute function private.require_room_interactive_player();

drop trigger if exists require_interactive_player_on_heist_attempts on public.clue_heist_attempts;
create trigger require_interactive_player_on_heist_attempts
before insert on public.clue_heist_attempts
for each row execute function private.require_round_interactive_player();
