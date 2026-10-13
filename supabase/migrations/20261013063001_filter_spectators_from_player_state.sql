-- Keep the display lifecycle member out of phone-facing player totals and the
-- leaderboard while preserving the audited state builder unchanged.

alter function public.get_player_game_state(uuid)
rename to get_player_game_state_unfiltered;

alter function public.get_player_game_state_unfiltered(uuid)
set schema private;

revoke all on function private.get_player_game_state_unfiltered(uuid)
from public, anon, authenticated;

create or replace function public.get_player_game_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_result jsonb;
  v_leaderboard jsonb;
begin
  v_result := private.get_player_game_state_unfiltered(p_room_id);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'name', rp.nickname,
      'score', rp.score,
      'is_me', rp.user_id = v_user,
      'is_host', rp.user_id = r.host_id
    )
    order by rp.score desc, rp.joined_at asc
  ), '[]'::jsonb)
  into v_leaderboard
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id and rp.role in ('host', 'player');

  v_result := jsonb_set(
    v_result,
    '{total_players}',
    to_jsonb((
      select count(*)
      from public.room_players rp
      where rp.room_id = p_room_id and rp.role in ('host', 'player')
    )),
    true
  );

  v_result := jsonb_set(v_result, '{leaderboard}', v_leaderboard, true);
  return v_result;
end;
$$;

revoke all on function public.get_player_game_state(uuid) from public, anon;
grant execute on function public.get_player_game_state(uuid) to authenticated;
