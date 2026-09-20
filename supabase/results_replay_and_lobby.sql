-- Host-controlled post-game actions that move the entire room together.

create or replace function public.host_replay_game(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_template_code text;
  v_selection text;
  v_result jsonb;
begin
  if v_user is null then raise exception 'Sign in required'; end if;

  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status = 'results'
  ) then
    raise exception 'Only the room host can replay a finished game';
  end if;

  select rt.code into v_template_code
  from public.game_rounds gr
  join public.round_templates rt on rt.id = gr.template_id
  where gr.room_id = p_room_id
  order by gr.position
  limit 1;

  if v_template_code is null then raise exception 'Previous game could not be found'; end if;

  v_selection := case v_template_code
    when 'trivia_vault_kenya' then 'trivia-kenya'
    when 'trivia_vault_scitech' then 'trivia-scitech'
    when 'trivia_vault_mix' then 'trivia-mix'
    when 'flag_frenzy_africa' then 'flags'
    when 'who_am_i_kenya' then 'who'
    when 'clue_heist_classic' then 'image'
    else null
  end;

  v_result := public.start_game(p_room_id, v_template_code);

  if v_selection is not null then
    update public.rooms
    set selected_game = v_selection, updated_at = now()
    where id = p_room_id;
  end if;

  return v_result || jsonb_build_object(
    'replayed', true,
    'template_code', v_template_code,
    'selected_game', v_selection
  );
end;
$$;

create or replace function public.host_return_to_lobby(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_template_code text;
  v_selection text;
begin
  if v_user is null then raise exception 'Sign in required'; end if;

  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status = 'results'
  ) then
    raise exception 'Only the room host can return this game to the lobby';
  end if;

  select rt.code into v_template_code
  from public.game_rounds gr
  join public.round_templates rt on rt.id = gr.template_id
  where gr.room_id = p_room_id
  order by gr.position
  limit 1;

  v_selection := case v_template_code
    when 'trivia_vault_kenya' then 'trivia-kenya'
    when 'trivia_vault_scitech' then 'trivia-scitech'
    when 'trivia_vault_mix' then 'trivia-mix'
    when 'flag_frenzy_africa' then 'flags'
    when 'who_am_i_kenya' then 'who'
    when 'clue_heist_classic' then 'image'
    else 'trivia-kenya'
  end;

  update public.game_rounds
  set status = 'closed', closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('pending', 'open', 'revealed');

  update public.room_players
  set score = 0
  where room_id = p_room_id;

  update public.rooms
  set status = 'lobby',
      phase = 'lobby',
      selected_game = v_selection,
      game_title = null,
      current_round_id = null,
      round_ends_at = null,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'returned_to_lobby', true,
    'selected_game', v_selection
  );
end;
$$;

revoke all on function public.host_replay_game(uuid) from public, anon;
revoke all on function public.host_return_to_lobby(uuid) from public, anon;
grant execute on function public.host_replay_game(uuid) to authenticated;
grant execute on function public.host_return_to_lobby(uuid) to authenticated;
