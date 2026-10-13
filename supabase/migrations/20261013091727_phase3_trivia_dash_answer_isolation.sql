-- Phase 3 release hardening: Trivia Dash owns its answer path instead of
-- inheriting whichever Classic-game submit_game_answer version is installed.
-- This keeps its participant counting and rollout surface isolated from the
-- five existing live modes.

create or replace function public.submit_trivia_dash_answer(
  p_round_id uuid,
  p_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_round public.game_rounds%rowtype;
  v_room public.rooms%rowtype;
  v_correct boolean;
  v_points integer := 0;
  v_participant_count integer := 0;
  v_answer_count integer := 0;
  v_inserted boolean := false;
begin
  if v_user is null then
    raise exception 'Sign in before answering';
  end if;

  select * into v_round
  from public.game_rounds
  where id = p_round_id
  for update;

  if not found then raise exception 'Round not found'; end if;

  select * into v_room
  from public.rooms
  where id = v_round.room_id;

  if not found
     or v_room.selected_game is distinct from 'trivia_dash'
     or v_room.current_round_id is distinct from p_round_id then
    raise exception 'This round is not part of Trivia Dash';
  end if;
  if v_room.status <> 'playing' or v_room.phase not in ('playing', 'all_answered') then
    raise exception 'Trivia Dash is not accepting answers';
  end if;
  if v_round.status <> 'open' then
    raise exception 'This round is not currently accepting answers';
  end if;
  if v_round.closes_at is not null and now() > v_round.closes_at + interval '2 seconds' then
    raise exception 'Time is up for this question';
  end if;

  if not exists (
    select 1
    from public.room_players rp
    join public.trivia_dash_player_state dash
      on dash.room_player_id = rp.id
     and dash.room_id = rp.room_id
    where rp.room_id = v_round.room_id
      and rp.user_id = v_user
      and rp.role in ('host', 'player')
      and dash.player_id = v_user
  ) then
    raise exception 'You are not an active Trivia Dash player';
  end if;

  select option.is_correct into v_correct
  from public.question_options option
  where option.id = p_option_id
    and option.question_id = v_round.question_id;

  if v_correct is null then
    raise exception 'Selected option is invalid for this question';
  end if;

  select case when v_correct then coalesce(question.base_points, 100) else 0 end
  into v_points
  from public.questions question
  where question.id = v_round.question_id;

  insert into public.player_answers
    (round_id, room_id, player_id, selected_option_id, is_correct, points_awarded, answered_at)
  values
    (v_round.id, v_round.room_id, v_user, p_option_id, v_correct, v_points, now())
  on conflict (round_id, player_id) do nothing
  returning true into v_inserted;

  if not coalesce(v_inserted, false) then
    raise exception 'You have already locked in your answer for this round';
  end if;

  select count(*) into v_participant_count
  from public.trivia_dash_player_state dash
  join public.room_players rp on rp.id = dash.room_player_id
  where dash.room_id = v_round.room_id
    and rp.role in ('host', 'player');

  select count(*) into v_answer_count
  from public.player_answers answer
  join public.trivia_dash_player_state dash
    on dash.room_id = answer.room_id
   and dash.player_id = answer.player_id
  join public.room_players rp on rp.id = dash.room_player_id
  where answer.round_id = v_round.id
    and rp.role in ('host', 'player');

  if v_participant_count > 0 and v_answer_count >= v_participant_count then
    update public.game_rounds
    set closes_at = least(coalesce(closes_at, now()), now())
    where id = v_round.id;

    update public.rooms
    set phase = 'all_answered',
        round_ends_at = null,
        state_version = state_version + 1,
        last_transition_at = now(),
        updated_at = now()
    where id = v_round.room_id and phase = 'playing';
  else
    update public.rooms
    set state_version = state_version + 1,
        updated_at = now()
    where id = v_round.room_id;
  end if;

  return jsonb_build_object(
    'accepted', true,
    'has_answered', true,
    'answered_count', v_answer_count,
    'participant_count', v_participant_count,
    'all_answered', v_participant_count > 0 and v_answer_count >= v_participant_count
  );
end;
$$;

revoke all on function public.submit_trivia_dash_answer(uuid, uuid) from public, anon;
grant execute on function public.submit_trivia_dash_answer(uuid, uuid) to authenticated;
