-- Correct the first spectator guard with table-shape-specific triggers.

drop trigger if exists require_interactive_player_on_answers on public.player_answers;
drop trigger if exists require_interactive_player_on_who_clues on public.who_am_i_clues;
drop trigger if exists require_interactive_player_on_heist_attempts on public.clue_heist_attempts;
drop function if exists private.require_interactive_player();

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

create trigger require_interactive_player_on_answers
before insert on public.player_answers
for each row execute function private.require_round_interactive_player();

create trigger require_interactive_player_on_who_clues
before insert on public.who_am_i_clues
for each row execute function private.require_room_interactive_player();

create trigger require_interactive_player_on_heist_attempts
before insert on public.clue_heist_attempts
for each row execute function private.require_round_interactive_player();
