-- Phase 3 performance gate: selecting 12 questions previously ran two
-- correlated option-count scans and an accidental nested-loop history join
-- across the full trivia bank. Rank narrow question ids once, then validate
-- only the 12 selected questions before creating any rounds.

create or replace function public.start_trivia_dash(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_room public.rooms%rowtype;
  v_template_id uuid;
  v_question public.questions%rowtype;
  v_position smallint := 0;
  v_round_id uuid;
  v_first_round_id uuid;
  v_first_closes_at timestamptz;
  v_option_count integer;
  v_correct_count integer;
  v_correct_slots smallint[] := array[1, 2, 3, 4]::smallint[];
  v_correct_slot smallint;
begin
  if v_user is null then raise exception 'Sign in before starting a game'; end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'Room not found'; end if;
  if v_room.host_id <> v_user or v_room.status not in ('lobby', 'results') then
    raise exception 'Only the room host can start this lobby';
  end if;

  select id into v_template_id
  from public.round_templates
  where code = 'trivia_dash_classic' and is_active;

  if v_template_id is null then raise exception 'Trivia Dash template is not active'; end if;

  delete from public.player_answers where room_id = p_room_id;
  delete from public.game_rounds where room_id = p_room_id;
  delete from public.trivia_dash_player_state where room_id = p_room_id;
  update public.room_players set score = 0 where room_id = p_room_id;

  insert into public.trivia_dash_player_state (room_id, room_player_id, player_id)
  select rp.room_id, rp.id, rp.user_id
  from public.room_players rp
  where rp.room_id = p_room_id and rp.role in ('host', 'player');

  for v_question in
    with ranked_question_ids as (
      select
        q.id,
        case when q.difficulty <= 2 then 1 when q.difficulty = 3 then 2 else 3 end as bucket,
        row_number() over (
          partition by case when q.difficulty <= 2 then 1 when q.difficulty = 3 then 2 else 3 end
          order by random()
        ) as bucket_rank
      from public.questions q
      where q.status = 'approved'
        and q.game_mode = 'trivia'
    )
    select q.*
    from ranked_question_ids ranked
    join public.questions q on q.id = ranked.id
    where ranked.bucket_rank <= 4
    order by ranked.bucket, ranked.bucket_rank
  loop
    select count(*), count(*) filter (where option.is_correct)
    into v_option_count, v_correct_count
    from public.question_options option
    where option.question_id = v_question.id;

    if v_option_count <> 4 or v_correct_count <> 1 then
      raise exception 'Trivia Dash selected an invalid question. No game was started.';
    end if;

    v_position := v_position + 1;

    if mod(v_position - 1, 4) = 0 then
      select array_agg(slot::smallint order by random())
      into v_correct_slots
      from generate_series(1, 4) as slot;
    end if;
    v_correct_slot := v_correct_slots[mod(v_position - 1, 4) + 1];

    if v_position = 1 then
      v_first_closes_at := now() + interval '25 seconds';
      insert into public.game_rounds
        (room_id, template_id, question_id, position, status, opens_at, closes_at)
      values
        (p_room_id, v_template_id, v_question.id, v_position, 'open', now(), v_first_closes_at)
      returning id into v_round_id;
      v_first_round_id := v_round_id;
    else
      insert into public.game_rounds
        (room_id, template_id, question_id, position, status, opens_at, closes_at)
      values
        (p_room_id, v_template_id, v_question.id, v_position, 'pending', null, null)
      returning id into v_round_id;
    end if;

    with shuffled_wrong_options as (
      select option.id, row_number() over (order by random()) as shuffle_number
      from public.question_options option
      where option.question_id = v_question.id and not option.is_correct
    ), shuffled_open_slots as (
      select slot, row_number() over (order by random()) as shuffle_number
      from generate_series(1, 4) as slot
      where slot <> v_correct_slot
    ), dealt_options as (
      select option.id as option_id, v_correct_slot as option_position
      from public.question_options option
      where option.question_id = v_question.id and option.is_correct
      union all
      select wrong_option.id, open_slot.slot::smallint
      from shuffled_wrong_options wrong_option
      join shuffled_open_slots open_slot using (shuffle_number)
    )
    insert into public.round_option_orders (round_id, option_id, position)
    select v_round_id, option_id, option_position
    from dealt_options;

    insert into private.question_play_history (question_id, last_played_at, times_played)
    values (v_question.id, now(), 1)
    on conflict (question_id) do update
    set last_played_at = excluded.last_played_at,
        times_played = private.question_play_history.times_played + 1;
  end loop;

  if v_position <> 12 then
    raise exception 'Trivia Dash needs 12 eligible questions, but only % matched. No game was started.', v_position;
  end if;

  update public.rooms
  set selected_game = 'trivia_dash',
      game_title = 'Trivia Dash',
      status = 'playing',
      phase = 'playing',
      state = coalesce(state, '{}'::jsonb) || jsonb_build_object(
        'trivia_dash_board_length', 24,
        'trivia_dash_total_rounds', 12
      ),
      current_round_id = v_first_round_id,
      round_ends_at = v_first_closes_at,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'room_id', p_room_id,
    'round_count', 12,
    'game_mode', 'trivia_dash',
    'first_round_id', v_first_round_id,
    'closes_at', v_first_closes_at
  );
end;
$$;

revoke all on function public.start_trivia_dash(uuid) from public, anon;
grant execute on function public.start_trivia_dash(uuid) to authenticated;
