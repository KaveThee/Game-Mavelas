-- Trivia Dash is intentionally isolated from the existing game RPCs. The
-- Classics keep their current behaviour while this mode is verified behind a
-- feature flag.

alter table public.round_templates
  drop constraint if exists round_templates_game_mode_check;

alter table public.round_templates
  add constraint round_templates_game_mode_check
  check (game_mode = any (array[
    'trivia'::text,
    'flag_frenzy'::text,
    'who_am_i'::text,
    'guess_image'::text,
    'logo_quiz'::text,
    'trivia_dash'::text
  ]));

insert into public.round_templates (code, title, game_mode, description, is_active)
values (
  'trivia_dash_classic',
  'Trivia Dash',
  'trivia_dash',
  'Twelve simultaneous trivia rounds on a shared 24-space race board.',
  true
)
on conflict (code) do update
set title = excluded.title,
    game_mode = excluded.game_mode,
    description = excluded.description,
    is_active = excluded.is_active;

create table if not exists public.trivia_dash_player_state (
  room_id uuid not null references public.rooms(id) on delete cascade,
  room_player_id uuid not null references public.room_players(id) on delete cascade,
  player_id uuid not null,
  position smallint not null default 0 check (position between 0 and 24),
  correct_answers smallint not null default 0 check (correct_answers between 0 and 12),
  correct_streak smallint not null default 0 check (correct_streak between 0 and 12),
  last_scored_round smallint not null default 0 check (last_scored_round between 0 and 12),
  updated_at timestamptz not null default now(),
  primary key (room_id, player_id),
  unique (room_player_id),
  foreign key (room_id, player_id)
    references public.room_players(room_id, user_id)
    on delete cascade
);

create index if not exists trivia_dash_player_state_race_idx
  on public.trivia_dash_player_state (room_id, position desc, correct_answers desc);

alter table public.trivia_dash_player_state enable row level security;
revoke all on table public.trivia_dash_player_state from anon, authenticated;

create or replace function public.create_trivia_dash_room(p_nickname text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_nickname text := btrim(p_nickname);
  v_code text;
  v_room public.rooms%rowtype;
  v_attempt smallint := 0;
begin
  if v_user is null then raise exception 'Sign in before creating a room'; end if;
  if char_length(v_nickname) not between 2 and 24 then
    raise exception 'Nickname must be between 2 and 24 characters';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text || v_user::text), 1, 6));
    begin
      insert into public.rooms (code, host_id, selected_game, status, phase)
      values (v_code, v_user, 'trivia-dash', 'lobby', 'lobby')
      returning * into v_room;
      exit;
    exception when unique_violation then
      if v_attempt >= 10 then raise exception 'Could not allocate a unique room code'; end if;
    end;
  end loop;

  insert into public.room_players (room_id, user_id, nickname, role)
  values (v_room.id, v_user, v_nickname, 'host');

  return jsonb_build_object(
    'id', v_room.id,
    'code', v_room.code,
    'status', v_room.status,
    'host_id', v_room.host_id,
    'selected_game', v_room.selected_game
  );
end;
$$;

create or replace function public.start_trivia_dash(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_template_id uuid;
  v_question record;
  v_position smallint := 0;
  v_round_id uuid;
  v_first_round_id uuid;
  v_first_closes_at timestamptz;
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
    with ranked_questions as (
      select
        q.*,
        case when q.difficulty <= 2 then 1 when q.difficulty = 3 then 2 else 3 end as bucket,
        row_number() over (
          partition by case when q.difficulty <= 2 then 1 when q.difficulty = 3 then 2 else 3 end
          order by h.last_played_at nulls first, random()
        ) as bucket_rank
      from public.questions q
      left join private.question_play_history h on h.question_id = q.id
      where q.status = 'approved'
        and q.game_mode = 'trivia'
        and (select count(*) from public.question_options qo where qo.question_id = q.id) = 4
        and (select count(*) from public.question_options qo where qo.question_id = q.id and qo.is_correct) = 1
    )
    select *
    from ranked_questions
    where bucket_rank <= 4
    order by bucket, bucket_rank
  loop
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
      select qo.id, row_number() over (order by random()) as shuffle_number
      from public.question_options qo
      where qo.question_id = v_question.id and not qo.is_correct
    ), shuffled_open_slots as (
      select slot, row_number() over (order by random()) as shuffle_number
      from generate_series(1, 4) as slot
      where slot <> v_correct_slot
    ), dealt_options as (
      select qo.id as option_id, v_correct_slot as option_position
      from public.question_options qo
      where qo.question_id = v_question.id and qo.is_correct
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

create or replace function public.select_trivia_dash_room(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in required'; end if;

  update public.rooms
  set selected_game = 'trivia-dash',
      phase = 'lobby',
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id
    and host_id = v_user
    and status in ('lobby', 'results');

  if not found then raise exception 'Only the room host can select a game'; end if;
  return jsonb_build_object('room_id', p_room_id, 'selected_game', 'trivia-dash');
end;
$$;

create or replace function public.reveal_trivia_dash_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_round public.game_rounds%rowtype;
begin
  if v_user is null or not exists (
    select 1 from public.room_players
    where room_id = p_room_id and user_id = v_user and role in ('host', 'player')
  ) then
    raise exception 'You are not in this room';
  end if;

  select * into v_room
  from public.rooms
  where id = p_room_id
  for update;

  if not found then raise exception 'Room not found'; end if;
  if v_room.selected_game <> 'trivia_dash' then raise exception 'This room is not playing Trivia Dash'; end if;
  if v_room.phase = 'revealed' then
    return jsonb_build_object('revealed', true, 'already_revealed', true);
  end if;
  if v_room.status <> 'playing' then raise exception 'Game is not active'; end if;

  select * into v_round
  from public.game_rounds
  where id = v_room.current_round_id and status = 'open'
  for update;

  if not found then raise exception 'Round is no longer open'; end if;
  if not (
    (v_room.phase = 'all_answered' and v_room.last_transition_at <= now() - interval '3 seconds')
    or (v_room.phase = 'playing' and v_round.closes_at <= now())
  ) then
    raise exception 'Reveal is not ready';
  end if;

  insert into public.player_answers
    (round_id, room_id, player_id, free_text_answer, is_correct, points_awarded, answered_at)
  select
    v_round.id,
    p_room_id,
    rp.user_id,
    '__timeout__',
    false,
    0,
    now()
  from public.room_players rp
  where rp.room_id = p_room_id
    and rp.role in ('host', 'player')
    and not exists (
      select 1 from public.player_answers pa
      where pa.round_id = v_round.id and pa.player_id = rp.user_id
    )
  on conflict (round_id, player_id) do nothing;

  update public.trivia_dash_player_state dash
  set position = least(
        24,
        dash.position + case
          when answer.is_correct then 2 + case when mod(dash.correct_streak + 1, 3) = 0 then 1 else 0 end
          else 0
        end
      ),
      correct_answers = dash.correct_answers + case when answer.is_correct then 1 else 0 end,
      correct_streak = case when answer.is_correct then dash.correct_streak + 1 else 0 end,
      last_scored_round = v_round.position,
      updated_at = now()
  from public.player_answers answer
  where answer.round_id = v_round.id
    and answer.player_id = dash.player_id
    and dash.room_id = p_room_id
    and dash.last_scored_round < v_round.position;

  update public.room_players player
  set score = player.score + answer.points_awarded
  from public.player_answers answer
  where answer.round_id = v_round.id
    and answer.player_id = player.user_id
    and player.room_id = p_room_id
    and answer.is_correct;

  update public.game_rounds
  set status = 'revealed', closes_at = least(coalesce(closes_at, now()), now())
  where id = v_round.id;

  update public.rooms
  set phase = 'revealed',
      round_ends_at = null,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object('revealed', true, 'round_id', v_round.id);
end;
$$;

create or replace function public.advance_trivia_dash_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_current_round public.game_rounds%rowtype;
  v_next_round public.game_rounds%rowtype;
  v_closes_at timestamptz;
begin
  if v_user is null or not exists (
    select 1 from public.room_players
    where room_id = p_room_id and user_id = v_user and role in ('host', 'player')
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
  if v_room.selected_game <> 'trivia_dash' or v_room.status <> 'playing'
     or v_room.phase <> 'revealed'
     or v_room.last_transition_at > now() - interval '6 seconds' then
    raise exception 'Next round is not ready';
  end if;

  select * into v_current_round
  from public.game_rounds
  where id = v_room.current_round_id
  for update;

  if not found then raise exception 'Current round not found'; end if;
  if exists (
    select 1
    from public.trivia_dash_player_state dash
    join public.room_players rp on rp.id = dash.room_player_id
    where dash.room_id = p_room_id
      and rp.role in ('host', 'player')
      and dash.last_scored_round < v_current_round.position
  ) then
    raise exception 'Every active player must be scored before the round can advance';
  end if;

  update public.game_rounds
  set status = 'closed', closes_at = coalesce(closes_at, now())
  where id = v_current_round.id;

  select * into v_next_round
  from public.game_rounds
  where room_id = p_room_id and status = 'pending'
  order by position
  limit 1
  for update;

  if not found then
    update public.rooms
    set status = 'results',
        phase = 'results',
        current_round_id = null,
        round_ends_at = null,
        state_version = state_version + 1,
        last_transition_at = now(),
        updated_at = now()
    where id = p_room_id;
    return jsonb_build_object('finished', true);
  end if;

  v_closes_at := now() + interval '25 seconds';

  update public.game_rounds
  set status = 'open', opens_at = now(), closes_at = v_closes_at
  where id = v_next_round.id;

  update public.rooms
  set phase = 'playing',
      current_round_id = v_next_round.id,
      round_ends_at = v_closes_at,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object(
    'finished', false,
    'round_id', v_next_round.id,
    'position', v_next_round.position,
    'closes_at', v_closes_at
  );
end;
$$;

create or replace function public.get_public_trivia_dash_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'room_code', room.code,
    'status', room.status,
    'phase', coalesce(room.phase, room.status),
    'game_mode', room.selected_game,
    'game_title', room.game_title,
    'state_version', room.state_version,
    'round_ends_at', room.round_ends_at,
    'board_length', 24,
    'current_round', coalesce(round.position, 0),
    'total_rounds', 12,
    'question', case when round.id is null then null else jsonb_build_object(
      'round_id', round.id,
      'prompt', question.prompt,
      'status', round.status,
      'opens_at', round.opens_at,
      'closes_at', round.closes_at,
      'options', coalesce((
        select jsonb_agg(jsonb_build_object(
          'label', chr(64 + coalesce(option_order.position, option.position)),
          'text', option.option_text,
          'is_correct', case when round.status = 'revealed' then option.is_correct else null end
        ) order by coalesce(option_order.position, option.position))
        from public.question_options option
        left join public.round_option_orders option_order
          on option_order.round_id = round.id and option_order.option_id = option.id
        where option.question_id = question.id
      ), '[]'::jsonb),
      'correct_option', case when round.status = 'revealed' then (
        select option.option_text
        from public.question_options option
        where option.question_id = question.id and option.is_correct
        limit 1
      ) else null end,
      'explanation', case when round.status = 'revealed' then question.explanation else null end
    ) end,
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', player.id,
        'name', player.nickname,
        'role', player.role,
        'position', dash.position,
        'score', player.score,
        'has_answered', case when round.id is null then false else exists (
          select 1 from public.player_answers answer
          where answer.round_id = round.id and answer.player_id = player.user_id
        ) end,
        'is_correct', case when round.status = 'revealed' then (
          select answer.is_correct from public.player_answers answer
          where answer.round_id = round.id and answer.player_id = player.user_id
        ) else null end,
        'points_awarded', case when round.status = 'revealed' then coalesce((
          select answer.points_awarded from public.player_answers answer
          where answer.round_id = round.id and answer.player_id = player.user_id
        ), 0) else null end
      ) order by dash.position desc, player.score desc, player.joined_at asc)
      from public.room_players player
      join public.trivia_dash_player_state dash on dash.room_player_id = player.id
      where player.room_id = room.id and player.role in ('host', 'player')
    ), '[]'::jsonb),
    'winner_ids', case when room.status = 'results' then coalesce((
      select jsonb_agg(player.id order by player.joined_at)
      from public.room_players player
      join public.trivia_dash_player_state dash on dash.room_player_id = player.id
      where player.room_id = room.id
        and dash.position = (
          select max(leader.position)
          from public.trivia_dash_player_state leader
          where leader.room_id = room.id
        )
    ), '[]'::jsonb) else '[]'::jsonb end
  )
  from public.rooms room
  left join public.game_rounds round on round.id = room.current_round_id
  left join public.questions question on question.id = round.question_id
  where room.code = upper(trim(p_room_code))
    and room.selected_game = 'trivia_dash';
$$;

create or replace function public.get_trivia_dash_player_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_round public.game_rounds%rowtype;
  v_question public.questions%rowtype;
  v_player public.room_players%rowtype;
  v_dash public.trivia_dash_player_state%rowtype;
  v_answer public.player_answers%rowtype;
begin
  if v_user is null then raise exception 'Sign in required'; end if;

  select * into v_room from public.rooms where id = p_room_id;
  if not found then raise exception 'Room not found'; end if;
  if v_room.selected_game <> 'trivia_dash' then raise exception 'This room is not playing Trivia Dash'; end if;

  select * into v_player
  from public.room_players
  where room_id = p_room_id and user_id = v_user and role in ('host', 'player');
  if not found then raise exception 'You are not a player in this room'; end if;

  select * into v_dash
  from public.trivia_dash_player_state
  where room_id = p_room_id and player_id = v_user;

  if v_room.current_round_id is not null then
    select * into v_round from public.game_rounds where id = v_room.current_round_id;
    select * into v_question from public.questions where id = v_round.question_id;
    select * into v_answer
    from public.player_answers
    where round_id = v_round.id and player_id = v_user;
  end if;

  return jsonb_build_object(
    'room_id', v_room.id,
    'room_code', v_room.code,
    'status', v_room.status,
    'phase', coalesce(v_room.phase, v_room.status),
    'is_host', v_room.host_id = v_user,
    'host_name', coalesce((
      select host_player.nickname
      from public.room_players host_player
      where host_player.room_id = p_room_id and host_player.user_id = v_room.host_id
    ), 'Host'),
    'selected_game', v_room.selected_game,
    'state_version', v_room.state_version,
    'board_length', 24,
    'current_round', coalesce(v_round.position, 0),
    'total_rounds', 12,
    'my_position', coalesce(v_dash.position, 0),
    'my_score', coalesce(v_player.score, 0),
    'my_streak', coalesce(v_dash.correct_streak, 0),
    'total_players', (
      select count(*) from public.room_players participant
      where participant.room_id = p_room_id and participant.role in ('host', 'player')
    ),
    'answered_count', case when v_round.id is null then 0 else (
      select count(*) from public.player_answers answer
      where answer.round_id = v_round.id
    ) end,
    'current_question', case when v_round.id is null then null else jsonb_build_object(
      'round_id', v_round.id,
      'position', v_round.position,
      'total_rounds', 12,
      'prompt', v_question.prompt,
      'game_mode', 'trivia_dash',
      'duration_seconds', 25,
      'status', v_round.status,
      'opens_at', v_round.opens_at,
      'closes_at', v_round.closes_at,
      'options', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', option.id,
          'label', chr(64 + coalesce(option_order.position, option.position)),
          'text', option.option_text
        ) order by coalesce(option_order.position, option.position))
        from public.question_options option
        left join public.round_option_orders option_order
          on option_order.round_id = v_round.id and option_order.option_id = option.id
        where option.question_id = v_question.id
      ), '[]'::jsonb)
    ) end,
    'my_answer', jsonb_build_object(
      'has_answered', v_answer.id is not null,
      'timed_out', coalesce(v_answer.free_text_answer = '__timeout__', false),
      'selected_option_id', v_answer.selected_option_id,
      'is_revealed', coalesce(v_round.status = 'revealed', false),
      'is_correct', case when v_round.status = 'revealed' then v_answer.is_correct else null end,
      'points_awarded', case when v_round.status = 'revealed' then v_answer.points_awarded else null end,
      'correct_option_id', case when v_round.status = 'revealed' then (
        select option.id from public.question_options option
        where option.question_id = v_question.id and option.is_correct
        limit 1
      ) else null end,
      'explanation', case when v_round.status = 'revealed' then v_question.explanation else null end
    ),
    'leaderboard', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', player.id,
        'name', player.nickname,
        'position', dash.position,
        'score', player.score,
        'is_me', player.user_id = v_user,
        'is_host', player.user_id = v_room.host_id
      ) order by dash.position desc, player.score desc, player.joined_at asc)
      from public.room_players player
      join public.trivia_dash_player_state dash on dash.room_player_id = player.id
      where player.room_id = p_room_id and player.role in ('host', 'player')
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.host_replay_trivia_dash(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_result jsonb;
begin
  if v_user is null or not exists (
    select 1 from public.rooms
    where id = p_room_id and host_id = v_user and status = 'results' and selected_game = 'trivia_dash'
  ) then
    raise exception 'Only the room host can replay a finished Trivia Dash game';
  end if;

  v_result := public.start_trivia_dash(p_room_id);
  return v_result || jsonb_build_object('replayed', true);
end;
$$;

create or replace function public.host_return_trivia_dash_to_lobby(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null or not exists (
    select 1 from public.rooms
    where id = p_room_id and host_id = v_user and status = 'results' and selected_game = 'trivia_dash'
  ) then
    raise exception 'Only the room host can return this Trivia Dash game to the lobby';
  end if;

  update public.game_rounds
  set status = 'closed', closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('pending', 'open', 'revealed');

  delete from public.trivia_dash_player_state where room_id = p_room_id;
  update public.room_players set score = 0 where room_id = p_room_id;

  update public.rooms
  set status = 'lobby',
      phase = 'lobby',
      selected_game = 'trivia-dash',
      game_title = null,
      current_round_id = null,
      round_ends_at = null,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object('returned_to_lobby', true, 'selected_game', 'trivia-dash');
end;
$$;

revoke all on function public.create_trivia_dash_room(text) from public, anon;
revoke all on function public.select_trivia_dash_room(uuid) from public, anon;
revoke all on function public.start_trivia_dash(uuid) from public, anon;
revoke all on function public.reveal_trivia_dash_round(uuid) from public, anon;
revoke all on function public.advance_trivia_dash_round(uuid) from public, anon;
revoke all on function public.get_public_trivia_dash_state(text) from public, anon;
revoke all on function public.get_trivia_dash_player_state(uuid) from public, anon;
revoke all on function public.host_replay_trivia_dash(uuid) from public, anon;
revoke all on function public.host_return_trivia_dash_to_lobby(uuid) from public, anon;

grant execute on function public.create_trivia_dash_room(text) to authenticated;
grant execute on function public.select_trivia_dash_room(uuid) to authenticated;
grant execute on function public.start_trivia_dash(uuid) to authenticated;
grant execute on function public.reveal_trivia_dash_round(uuid) to authenticated;
grant execute on function public.advance_trivia_dash_round(uuid) to authenticated;
grant execute on function public.get_public_trivia_dash_state(text) to authenticated;
grant execute on function public.get_trivia_dash_player_state(uuid) to authenticated;
grant execute on function public.host_replay_trivia_dash(uuid) to authenticated;
grant execute on function public.host_return_trivia_dash_to_lobby(uuid) to authenticated;
