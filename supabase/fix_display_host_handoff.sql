-- Display-first rooms should open with a concrete Trivia Vault branch selected.
update public.rooms
set selected_game='trivia-kenya', state_version=state_version+1, updated_at=now()
where status='lobby' and selected_game='trivia' and coalesce((state ->> 'display_first')::boolean,false);

create or replace function public.create_display_room()
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_display_user uuid := (select auth.uid()); v_code text; v_room public.rooms%rowtype; v_attempt smallint := 0;
begin
  if v_display_user is null then raise exception 'Sign in before opening a display room'; end if;
  loop
    v_attempt := v_attempt+1;
    v_code:=upper(substr(md5(random()::text || clock_timestamp()::text || v_display_user::text),1,6));
    begin
      insert into public.rooms(code,host_id,selected_game,status,phase,state)
      values(v_code,v_display_user,'trivia-kenya','lobby','lobby',jsonb_build_object('display_first',true,'awaiting_host',true))
      returning * into v_room;
      exit;
    exception when unique_violation then
      if v_attempt>=10 then raise exception 'Could not allocate a unique room code'; end if;
    end;
  end loop;
  return jsonb_build_object('id',v_room.id,'code',v_room.code,'status',v_room.status,'awaiting_host',true);
end;
$$;
revoke all on function public.create_display_room() from public,anon;
grant execute on function public.create_display_room() to authenticated;