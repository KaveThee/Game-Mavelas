-- Server-authoritative lobby selection for host controllers.
create or replace function public.select_room_game(p_room_id uuid, p_selected_game text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := auth.uid(); v_game text := lower(btrim(p_selected_game));
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if v_game not in ('trivia-kenya','trivia-scitech','trivia-mix','flags','who','image') then raise exception 'Unsupported game selection'; end if;
  update public.rooms
  set selected_game=v_game, phase='lobby', state_version=state_version+1, last_transition_at=now(), updated_at=now()
  where id=p_room_id and host_id=v_user and status in ('lobby','results');
  if not found then raise exception 'Only the room host can select a game'; end if;
  return jsonb_build_object('room_id',p_room_id,'selected_game',v_game);
end;
$$;
revoke all on function public.select_room_game(uuid,text) from public,anon;
grant execute on function public.select_room_game(uuid,text) to authenticated;