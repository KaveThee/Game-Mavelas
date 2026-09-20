-- Give every game a fresh, balanced answer layout.
-- Each block of four rounds uses A, B, C, and D exactly once for the
-- correct answer, while the incorrect answers are independently shuffled.

create or replace function public.start_game(p_room_id uuid, p_template_code text)
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
  v_first_round_id uuid := null;
  v_round_id uuid;
  v_first_duration smallint := 20;
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

  select coalesce(sum(question_count), 0) into v_expected
  from public.round_template_steps
  where template_id = v_template.id;

  delete from public.player_answers where room_id = p_room_id;
  delete from public.game_rounds where room_id = p_room_id;
  update public.room_players set score = 0 where room_id = p_room_id;

  for v_step in
    select * from public.round_template_steps
    where template_id = v_template.id
    order by position
  loop
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
      limit v_step.question_count
    loop
      v_position := v_position + 1;

      -- Deal a new random permutation of A-D at the start of every block.
      if mod(v_position - 1, 4) = 0 then
        select array_agg(slot::smallint order by random())
        into v_correct_slots
        from generate_series(1, 4) as slot;
      end if;
      v_correct_slot := v_correct_slots[mod(v_position - 1, 4) + 1];

      if v_position = 1 then
        v_first_duration := coalesce(v_question.duration_seconds, v_step.seconds_per_question, 20);
        v_first_closes_at := now() + (v_first_duration || ' seconds')::interval;
        insert into public.game_rounds
          (room_id, template_id, question_id, position, status, opens_at, closes_at)
        values
          (p_room_id, v_template.id, v_question.id, v_position, 'open', now(), v_first_closes_at)
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
    'closes_at', v_first_closes_at
  );
end;
$$;

revoke all on function public.start_game(uuid, text) from public, anon;
grant execute on function public.start_game(uuid, text) to authenticated;
