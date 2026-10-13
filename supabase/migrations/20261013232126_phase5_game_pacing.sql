-- Phase 5: one server-authoritative pacing contract for every live game.
-- Quiz modes give the shared display a short lead before controllers unlock.
-- Conversation modes start immediately and keep their longer turn clocks.

update public.round_template_steps rts
set seconds_per_question = case rts.position
  when 1 then 22
  when 2 then 20
  when 3 then 18
  else rts.seconds_per_question
end
from public.round_templates rt
where rt.id = rts.template_id
  and rt.game_mode = 'trivia';

create or replace function private.display_lead_seconds(p_game_mode text)
returns smallint
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when p_game_mode in ('trivia', 'flag_frenzy', 'logo_quiz') then 3
    else 0
  end::smallint;
$$;

create or replace function private.effective_round_duration(
  p_template_id uuid,
  p_position smallint,
  p_question_id uuid
)
returns smallint
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    case
      when rt.game_mode = 'flag_frenzy' then 30
      else (
        select timed_step.seconds_per_question
        from (
          select
            rts.seconds_per_question,
            sum(rts.question_count) over (order by rts.position) as round_ceiling
          from public.round_template_steps rts
          where rts.template_id = p_template_id
        ) timed_step
        where p_position <= timed_step.round_ceiling
        order by timed_step.round_ceiling
        limit 1
      )
    end,
    q.duration_seconds,
    20
  )::smallint
  from public.questions q
  left join public.round_templates rt on rt.id = p_template_id
  where q.id = p_question_id;
$$;

revoke all on function private.display_lead_seconds(text) from public, anon, authenticated;
revoke all on function private.effective_round_duration(uuid, smallint, uuid) from public, anon, authenticated;

create or replace function public.start_game(
  p_room_id uuid,
  p_template_code text,
  p_round_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_template public.round_templates%rowtype;
  v_step public.round_template_steps%rowtype;
  v_question public.questions%rowtype;
  v_position smallint := 0;
  v_total integer := 0;
  v_expected integer := 0;
  v_requested_count integer := null;
  v_step_count integer := 0;
  v_first_round_id uuid := null;
  v_round_id uuid;
  v_first_duration smallint := 20;
  v_first_opens_at timestamptz := null;
  v_first_closes_at timestamptz := null;
  v_correct_slots smallint[] := array[1, 2, 3, 4]::smallint[];
  v_correct_slot smallint;
begin
  if v_user is null then raise exception 'Sign in before starting a game'; end if;
  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status in ('lobby', 'results')
  ) then
    raise exception 'Only the room host can start this lobby';
  end if;

  select * into v_template
  from public.round_templates
  where code = p_template_code and is_active;
  if not found then raise exception 'Game template not found: %', p_template_code; end if;

  if v_template.game_mode = 'flag_frenzy' then
    select coalesce(
      p_round_count,
      case
        when r.state->>'flag_round_count' ~ '^[0-9]+$' then (r.state->>'flag_round_count')::integer
        else null
      end,
      15
    )
    into v_requested_count
    from public.rooms r
    where r.id = p_room_id;

    if v_requested_count not in (15, 30, 45, 60) then
      raise exception 'Flag Frenzy rounds must be 15, 30, 45, or 60';
    end if;
    v_expected := v_requested_count;
  else
    select coalesce(sum(question_count), 0) into v_expected
    from public.round_template_steps
    where template_id = v_template.id;
  end if;

  delete from public.player_answers where room_id = p_room_id;
  delete from public.game_rounds where room_id = p_room_id;
  update public.room_players set score = 0 where room_id = p_room_id;

  for v_step in
    select * from public.round_template_steps
    where template_id = v_template.id
    order by position
  loop
    if v_template.game_mode = 'flag_frenzy' then
      v_step_count := case v_step.position
        when 1 then round(v_requested_count * 0.30)::integer
        when 2 then round(v_requested_count * 0.40)::integer
        when 3 then v_requested_count
          - round(v_requested_count * 0.30)::integer
          - round(v_requested_count * 0.40)::integer
        else 0
      end;
    else
      v_step_count := v_step.question_count;
    end if;

    for v_question in
      select q.*
      from public.questions q
      left join private.question_play_history h on h.question_id = q.id
      where q.status = 'approved'
        and q.game_mode = v_template.game_mode
        and q.difficulty between v_step.difficulty_min and v_step.difficulty_max
        and (v_step.category_id is null or q.category_id = v_step.category_id)
        and not exists (
          select 1 from public.game_rounds gr
          where gr.room_id = p_room_id and gr.question_id = q.id
        )
      order by h.last_played_at nulls first, random()
      limit v_step_count
    loop
      v_position := v_position + 1;

      if mod(v_position - 1, 4) = 0 then
        select array_agg(slot::smallint order by random())
        into v_correct_slots
        from generate_series(1, 4) as slot;
      end if;
      v_correct_slot := v_correct_slots[mod(v_position - 1, 4) + 1];

      if v_position = 1 then
        v_first_duration := private.effective_round_duration(
          v_template.id,
          v_position,
          v_question.id
        );
        v_first_opens_at := now() + make_interval(
          secs => private.display_lead_seconds(v_template.game_mode)
        );
        v_first_closes_at := v_first_opens_at + make_interval(secs => v_first_duration);
        insert into public.game_rounds
          (room_id, template_id, question_id, position, status, opens_at, closes_at)
        values
          (p_room_id, v_template.id, v_question.id, v_position, 'open', v_first_opens_at, v_first_closes_at)
        returning id into v_round_id;
        v_first_round_id := v_round_id;
      else
        insert into public.game_rounds
          (room_id, template_id, question_id, position, status, opens_at, closes_at)
        values
          (p_room_id, v_template.id, v_question.id, v_position, 'pending', null, null)
        returning id into v_round_id;
      end if;

      with shuffled_wrong_options as (
        select o.id, row_number() over (order by random()) as shuffle_number
        from public.question_options o
        where o.question_id = v_question.id and not o.is_correct
      ), shuffled_open_slots as (
        select slot, row_number() over (order by random()) as shuffle_number
        from generate_series(1, 4) as slot
        where slot <> v_correct_slot
      ), dealt_options as (
        select o.id as option_id, v_correct_slot as option_position
        from public.question_options o
        where o.question_id = v_question.id and o.is_correct
        union all
        select o.id, s.slot::smallint
        from shuffled_wrong_options o
        join shuffled_open_slots s using (shuffle_number)
      )
      insert into public.round_option_orders (round_id, option_id, position)
      select v_round_id, option_id, option_position
      from dealt_options;

      insert into private.question_play_history (question_id, last_played_at, times_played)
      values (v_question.id, now(), 1)
      on conflict (question_id) do update
      set last_played_at = excluded.last_played_at,
          times_played = private.question_play_history.times_played + 1;

      v_total := v_total + 1;
    end loop;
  end loop;

  if v_total <> v_expected then
    raise exception 'Template % needs % unique questions, but only % matched. No game was started.',
      p_template_code, v_expected, v_total;
  end if;

  update public.rooms
  set selected_game = v_template.game_mode,
      game_title = v_template.title,
      status = 'playing',
      phase = 'playing',
      state = case
        when v_template.game_mode = 'flag_frenzy'
          then jsonb_set(coalesce(state, '{}'::jsonb), '{flag_round_count}', to_jsonb(v_requested_count), true)
        else state
      end,
      current_round_id = v_first_round_id,
      round_ends_at = v_first_closes_at,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'room_id', p_room_id,
    'round_count', v_total,
    'game_mode', v_template.game_mode,
    'first_round_id', v_first_round_id,
    'opens_at', v_first_opens_at,
    'closes_at', v_first_closes_at
  );
end;
$$;

create or replace function public.auto_advance_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room record;
  v_next_round record;
  v_duration smallint;
  v_opens_at timestamptz;
  v_closes_at timestamptz;
begin
  if v_user is null or not exists (
    select 1 from public.room_players
    where room_id = p_room_id and user_id = v_user
  ) then
    raise exception 'You are not in this room';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'Room not found'; end if;
  if v_room.status = 'results' then
    return jsonb_build_object('finished', true, 'already_finished', true);
  end if;
  if v_room.status <> 'playing' or v_room.phase <> 'revealed'
     or v_room.last_transition_at > now() - interval '6 seconds' then
    raise exception 'Next round is not ready';
  end if;

  update public.game_rounds
  set status = 'closed', closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('open', 'revealed');

  select gr.id, gr.position, gr.template_id, gr.question_id, q.game_mode
  into v_next_round
  from public.game_rounds gr
  join public.questions q on q.id = gr.question_id
  where gr.room_id = p_room_id and gr.status = 'pending'
  order by gr.position
  limit 1;

  if v_next_round.id is null then
    update public.rooms
    set status = 'results', phase = 'results', current_round_id = null,
        round_ends_at = null, state_version = state_version + 1,
        last_transition_at = now(), updated_at = now()
    where id = p_room_id;
    return jsonb_build_object('finished', true);
  end if;

  v_duration := private.effective_round_duration(
    v_next_round.template_id,
    v_next_round.position,
    v_next_round.question_id
  );
  v_opens_at := now() + make_interval(
    secs => private.display_lead_seconds(v_next_round.game_mode)
  );
  v_closes_at := v_opens_at + make_interval(secs => v_duration);

  update public.game_rounds
  set status = 'open', opens_at = v_opens_at, closes_at = v_closes_at
  where id = v_next_round.id;

  update public.rooms
  set phase = 'playing', current_round_id = v_next_round.id,
      round_ends_at = v_closes_at, state_version = state_version + 1,
      last_transition_at = now(), updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'finished', false,
    'round_id', v_next_round.id,
    'position', v_next_round.position,
    'opens_at', v_opens_at,
    'closes_at', v_closes_at,
    'duration_seconds', v_duration
  );
end;
$$;

create or replace function public.submit_game_answer(p_round_id uuid, p_option_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_round public.game_rounds%rowtype;
  v_correct boolean;
  v_points integer := 0;
  v_participant_count integer;
  v_answer_count integer;
  v_all_answered boolean := false;
begin
  if v_user is null then raise exception 'Sign in before answering'; end if;

  select * into v_round
  from public.game_rounds
  where id = p_round_id
  for update;

  if not found then raise exception 'Round not found'; end if;
  if v_round.status <> 'open' then raise exception 'This round is not currently accepting answers'; end if;
  if v_round.opens_at is not null and now() < v_round.opens_at then
    raise exception 'Answer pads are not open yet';
  end if;
  if v_round.closes_at is not null and now() > (v_round.closes_at + interval '2 seconds') then
    raise exception 'Time is up for this question';
  end if;

  if not exists (
    select 1 from public.room_players rp
    where rp.room_id = v_round.room_id
      and rp.user_id = v_user
      and rp.role in ('host', 'player')
  ) then
    raise exception 'You are not in this room';
  end if;

  if exists (
    select 1 from public.player_answers
    where round_id = p_round_id and player_id = v_user
  ) then
    raise exception 'You have already locked in your answer for this round';
  end if;

  select qo.is_correct into v_correct
  from public.question_options qo
  where qo.id = p_option_id and qo.question_id = v_round.question_id;
  if v_correct is null then raise exception 'Selected option is invalid for this question'; end if;

  select case
    when q.game_mode = 'trivia' then case
      when q.difficulty <= 1 then 100
      when q.difficulty = 2 then 150
      else 200
    end
    else coalesce(q.base_points, 100)
  end
  into v_points
  from public.questions q
  where q.id = v_round.question_id;

  if not v_correct then v_points := 0; end if;

  insert into public.player_answers
    (round_id, room_id, player_id, selected_option_id, is_correct, points_awarded, answered_at)
  values
    (v_round.id, v_round.room_id, v_user, p_option_id, v_correct, v_points, now());

  select count(*) into v_participant_count
  from public.room_players
  where room_id = v_round.room_id and role in ('host', 'player');

  select count(*) into v_answer_count
  from public.player_answers pa
  join public.room_players rp
    on rp.room_id = pa.room_id and rp.user_id = pa.player_id
  where pa.round_id = v_round.id and rp.role in ('host', 'player');

  v_all_answered := v_participant_count > 0 and v_answer_count >= v_participant_count;

  if v_all_answered then
    update public.game_rounds
    set closes_at = now()
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
    set state_version = state_version + 1, updated_at = now()
    where id = v_round.room_id;
  end if;

  return jsonb_build_object(
    'accepted', true,
    'has_answered', true,
    'answered_count', v_answer_count,
    'participant_count', v_participant_count,
    'all_answered', v_all_answered
  );
end;
$$;

revoke all on function public.start_game(uuid, text, integer) from public, anon;
revoke all on function public.auto_advance_round(uuid) from public, anon;
revoke all on function public.submit_game_answer(uuid, uuid) from public, anon;
grant execute on function public.start_game(uuid, text, integer) to authenticated;
grant execute on function public.auto_advance_round(uuid) to authenticated;
grant execute on function public.submit_game_answer(uuid, uuid) to authenticated;
