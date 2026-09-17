-- Keep direct host-created rooms compatible with the Trivia Vault branches.
create or replace function public.create_game_room(p_nickname text, p_selected_game text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid()); v_nickname text := btrim(p_nickname); v_game text := lower(btrim(p_selected_game));
  v_code text; v_room public.rooms%rowtype; v_attempt smallint := 0;
begin
  if v_user is null then raise exception 'Sign in before creating a room'; end if;
  if char_length(v_nickname) not between 2 and 24 then raise exception 'Nickname must be between 2 and 24 characters'; end if;
  if v_game not in ('trivia','trivia-kenya','trivia-scitech','trivia-mix','flags','flag_frenzy','who','who_am_i','image','guess_image') then raise exception 'Unsupported game selection'; end if;
  loop
    v_attempt := v_attempt + 1;
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text || v_user::text), 1, 6));
    begin
      insert into public.rooms (code,host_id,selected_game,status,phase) values (v_code,v_user,v_game,'lobby','lobby') returning * into v_room;
      exit;
    exception when unique_violation then
      if v_attempt >= 10 then raise exception 'Could not allocate a unique room code'; end if;
    end;
  end loop;
  insert into public.room_players (room_id,user_id,nickname,role) values (v_room.id,v_user,v_nickname,'host');
  return jsonb_build_object('id',v_room.id,'code',v_room.code,'status',v_room.status,'host_id',v_room.host_id,'selected_game',v_room.selected_game);
end;
$$;
revoke all on function public.create_game_room(text,text) from public,anon;
grant execute on function public.create_game_room(text,text) to authenticated;