-- Keep the full transactional implementation outside the exposed API schema
-- and return only lifecycle booleans to a departing controller. In particular,
-- another participant's auth user id must never be included in the response.

alter function public.leave_game_room(uuid) set schema private;

revoke all on function private.leave_game_room(uuid) from public, anon, authenticated;

create or replace function public.leave_game_room(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  v_result := private.leave_game_room(p_room_id);

  return (v_result - 'new_host_id') || jsonb_build_object(
    'host_transferred',
    coalesce((v_result ->> 'was_host')::boolean, false)
      and not coalesce((v_result ->> 'room_closed')::boolean, false)
  );
end;
$$;

revoke all on function public.leave_game_room(uuid) from public, anon;
grant execute on function public.leave_game_room(uuid) to authenticated;
