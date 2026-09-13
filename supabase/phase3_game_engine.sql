-- Phase 3 Playable Game Engine Migration
-- Idempotent, strict RLS, server-authoritative state for Trivia Rush and Flag Frenzy.

create extension if not exists pgcrypto;

-- 1. Ensure required room columns
alter table public.rooms
  add column if not exists phase text not null default 'lobby'
    check (phase in ('lobby', 'selected', 'playing', 'paused', 'revealed', 'results', 'closed')),
  add column if not exists game_title text,
  add column if not exists max_players smallint not null default 12
    check (max_players between 2 and 100),
  add column if not exists current_round_id uuid,
  add column if not exists state_version bigint not null default 0,
  add column if not exists last_transition_at timestamptz not null default now(),
  add column if not exists round_ends_at timestamptz;

-- 2. Ensure required room_players columns
alter table public.room_players
  add column if not exists role text not null default 'player'
    check (role in ('host', 'player', 'moderator', 'jury', 'spectator')),
  add column if not exists seat_no smallint,
  add column if not exists is_connected boolean not null default true,
  add column if not exists last_seen_at timestamptz not null default now();

-- 3. Ensure required game_rounds columns
alter table public.game_rounds
  add column if not exists closes_at timestamptz,
  add column if not exists opens_at timestamptz;

-- 4. Enable RLS on player answers
alter table public.player_answers enable row level security;
drop policy if exists "players read own answers" on public.player_answers;
create policy "players read own answers" on public.player_answers
  for select to authenticated using (player_id = (select auth.uid()));

drop policy if exists "players insert own answers" on public.player_answers;
create policy "players insert own answers" on public.player_answers
  for insert to authenticated with check (player_id = (select auth.uid()));

-- 5. Realtime publications
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'rooms') then
    alter publication supabase_realtime add table public.rooms;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_players') then
    alter publication supabase_realtime add table public.room_players;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_rounds') then
    alter publication supabase_realtime add table public.game_rounds;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'player_answers') then
    alter publication supabase_realtime add table public.player_answers;
  end if;
end $$;

-- 6. START GAME RPC (Host only, initializes rounds with duration and opens first round)
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
  v_first_round_id uuid := null;
  v_first_duration smallint := 20;
  v_first_closes_at timestamptz := null;
begin
  if v_user is null then raise exception 'Sign in before starting a game'; end if;
  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status in ('lobby', 'results')
  ) then
    raise exception 'Only the room host can start this lobby';
  end if;

  select * into v_template from public.round_templates
  where code = p_template_code;
  if not found then raise exception 'Game template not found: %', p_template_code; end if;

  -- Clean previous rounds & answers for a fresh run
  delete from public.player_answers where room_id = p_room_id;
  delete from public.game_rounds where room_id = p_room_id;

  -- Reset players scores for the new match
  update public.room_players set score = 0 where room_id = p_room_id;

  for v_step in
    select * from public.round_template_steps where template_id = v_template.id order by position
  loop
    for v_question in
      select q.* from public.questions q
      where q.status = 'approved'
        and q.game_mode = v_template.game_mode
        and q.difficulty between v_step.difficulty_min and v_step.difficulty_max
        and (v_step.category_id is null or q.category_id = v_step.category_id)
      order by random()
      limit v_step.question_count
    loop
      v_position := v_position + 1;
      if v_position = 1 then
        v_first_duration := coalesce(v_question.duration_seconds, v_step.seconds_per_question, 20);
        v_first_closes_at := now() + (v_first_duration || ' seconds')::interval;

        insert into public.game_rounds (room_id, template_id, question_id, position, status, opens_at, closes_at)
        values (p_room_id, v_template.id, v_question.id, v_position, 'open', now(), v_first_closes_at)
        returning id into v_first_round_id;
      else
        insert into public.game_rounds (room_id, template_id, question_id, position, status, opens_at, closes_at)
        values (p_room_id, v_template.id, v_question.id, v_position, 'pending', null, null);
      end if;
      v_total := v_total + 1;
    end loop;
  end loop;

  if v_total = 0 then raise exception 'No approved questions match template %', p_template_code; end if;

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

-- 7. SUBMIT GAME ANSWER RPC (Secure, timer-enforced, single answer, no answer leak)
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
begin
  if v_user is null then raise exception 'Sign in before answering'; end if;

  select * into v_round from public.game_rounds where id = p_round_id;
  if not found then raise exception 'Round not found'; end if;

  if v_round.status <> 'open' then
    raise exception 'This round is not currently accepting answers';
  end if;

  -- Timer enforcement with small 2-second grace period for network jitter
  if v_round.closes_at is not null and now() > (v_round.closes_at + interval '2 seconds') then
    raise exception 'Time is up for this question';
  end if;

  if not exists (
    select 1 from public.room_players rp
    where rp.room_id = v_round.room_id and rp.user_id = v_user
  ) then
    raise exception 'You are not a player in this room';
  end if;

  -- Check if already answered
  if exists (
    select 1 from public.player_answers
    where round_id = p_round_id and player_id = v_user
  ) then
    raise exception 'You have already locked in your answer for this round';
  end if;

  -- Verify option belongs to this round's question
  select qo.is_correct into v_correct from public.question_options qo
  where qo.id = p_option_id and qo.question_id = v_round.question_id;
  if v_correct is null then
    raise exception 'Selected option is invalid for this question';
  end if;

  select case when v_correct then coalesce(q.base_points, 100) else 0 end into v_points
  from public.questions q where q.id = v_round.question_id;

  insert into public.player_answers (round_id, room_id, player_id, selected_option_id, is_correct, points_awarded, answered_at)
  values (v_round.id, v_round.room_id, v_user, p_option_id, v_correct, v_points, now());

  update public.room_players
  set score = score + v_points
  where room_id = v_round.room_id and user_id = v_user;

  -- Note: Do NOT leak is_correct or points_awarded here; player gets revealed state when host reveals!
  return jsonb_build_object(
    'accepted', true,
    'has_answered', true
  );
end;
$$;

-- 8. HOST REVEAL ROUND RPC (Host only, closes submissions, transitions phase to revealed)
create or replace function public.host_reveal_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_round_id uuid;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status = 'playing'
  ) then
    raise exception 'Only the room host can reveal this round';
  end if;

  select id into v_round_id from public.game_rounds
  where room_id = p_room_id and status = 'open'
  order by position limit 1;

  if v_round_id is not null then
    update public.game_rounds
    set status = 'revealed',
        closes_at = coalesce(closes_at, now())
    where id = v_round_id;
  end if;

  update public.rooms
  set phase = 'revealed',
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object('revealed', true, 'round_id', v_round_id);
end;
$$;

-- 9. HOST ADVANCE ROUND RPC (Host only, moves from revealed/open to next round or results)
create or replace function public.host_advance_round(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_next_round record;
  v_duration smallint := 20;
  v_closes_at timestamptz;
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user and r.status = 'playing'
  ) then
    raise exception 'Only the room host can advance this round';
  end if;

  -- Close any open or revealed rounds
  update public.game_rounds
  set status = 'closed',
      closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('open', 'revealed');

  -- Find next pending round
  select gr.id, gr.position, q.duration_seconds
  into v_next_round
  from public.game_rounds gr
  join public.questions q on q.id = gr.question_id
  where gr.room_id = p_room_id and gr.status = 'pending'
  order by gr.position limit 1;

  if v_next_round.id is null then
    -- No more rounds: game is finished
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

  v_duration := coalesce(v_next_round.duration_seconds, 20);
  v_closes_at := now() + (v_duration || ' seconds')::interval;

  update public.game_rounds
  set status = 'open',
      opens_at = now(),
      closes_at = v_closes_at
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

-- 10. HOST END GAME RPC (Host only, immediately sets results)
create or replace function public.host_end_game(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Sign in required'; end if;
  if not exists (
    select 1 from public.rooms r
    where r.id = p_room_id and r.host_id = v_user
  ) then
    raise exception 'Only the room host can end the game';
  end if;

  update public.game_rounds
  set status = 'closed',
      closes_at = coalesce(closes_at, now())
  where room_id = p_room_id and status in ('open', 'revealed');

  update public.rooms
  set status = 'results',
      phase = 'results',
      current_round_id = null,
      round_ends_at = null,
      state_version = state_version + 1,
      last_transition_at = now(),
      updated_at = now()
  where id = p_room_id;

  return jsonb_build_object('ended', true);
end;
$$;

-- 11. COMPREHENSIVE PLAYER GAME STATE RECOVERY RPC
-- Single source of truth for phone controllers: recovers state on refresh,
-- hides answers during play, reveals answer and explanation only when revealed.
create or replace function public.get_player_game_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_room record;
  v_host_name text;
  v_round record;
  v_question record;
  v_my_answer record;
  v_total_players integer;
  v_answered_count integer := 0;
  v_total_rounds integer := 0;
  v_correct_opt_id uuid := null;
  v_explanation text := null;
  v_is_correct boolean := null;
  v_points integer := null;
  v_my_score integer := 0;
begin
  if v_user is null then raise exception 'Sign in required'; end if;

  select r.* into v_room from public.rooms r where r.id = p_room_id;
  if not found then raise exception 'Room not found'; end if;

  if not exists (
    select 1 from public.room_players rp where rp.room_id = p_room_id and rp.user_id = v_user
  ) then
    raise exception 'You are not a player in this room';
  end if;

  select score into v_my_score from public.room_players
  where room_id = p_room_id and user_id = v_user;

  select nickname into v_host_name from public.room_players
  where room_id = p_room_id and user_id = v_room.host_id;

  select count(*) into v_total_players from public.room_players
  where room_id = p_room_id;

  select count(*) into v_total_rounds from public.game_rounds
  where room_id = p_room_id;

  -- Active or revealed round
  select gr.* into v_round from public.game_rounds gr
  where gr.room_id = p_room_id and gr.status in ('open', 'revealed')
  order by gr.position limit 1;

  if v_round.id is not null then
    select q.*, m.asset_type as media_type, m.public_url as media_url, m.alt_text as media_alt
    into v_question
    from public.questions q
    left join public.media_assets m on m.id = q.media_id
    where q.id = v_round.question_id;

    select count(*) into v_answered_count from public.player_answers
    where round_id = v_round.id;

    select * into v_my_answer from public.player_answers
    where round_id = v_round.id and player_id = v_user;

    -- Only disclose answer details once revealed
    if v_round.status = 'revealed' then
      select qo.id into v_correct_opt_id from public.question_options qo
      where qo.question_id = v_question.id and qo.is_correct = true limit 1;

      v_explanation := v_question.explanation;
      if v_my_answer.id is not null then
        v_is_correct := v_my_answer.is_correct;
        v_points := v_my_answer.points_awarded;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'room_id', v_room.id,
    'room_code', v_room.code,
    'status', v_room.status,
    'phase', coalesce(v_room.phase, v_room.status),
    'is_host', (v_room.host_id = v_user),
    'host_name', coalesce(v_host_name, 'Host'),
    'selected_game', v_room.selected_game,
    'state_version', v_room.state_version,
    'my_score', coalesce(v_my_score, 0),
    'total_players', v_total_players,
    'answered_count', v_answered_count,
    'current_question', case when v_round.id is null then null else jsonb_build_object(
      'round_id', v_round.id,
      'position', v_round.position,
      'total_rounds', v_total_rounds,
      'prompt', v_question.prompt,
      'game_mode', v_question.game_mode,
      'duration_seconds', v_question.duration_seconds,
      'opens_at', v_round.opens_at,
      'closes_at', v_round.closes_at,
      'media', case when v_question.media_url is null then null else jsonb_build_object(
        'type', v_question.media_type,
        'url', v_question.media_url,
        'alt', v_question.media_alt
      ) end,
      'options', coalesce((
        select jsonb_agg(jsonb_build_object('id', qo.id, 'text', qo.option_text) order by qo.position)
        from public.question_options qo where qo.question_id = v_question.id
      ), '[]'::jsonb)
    ) end,
    'my_answer', jsonb_build_object(
      'has_answered', (v_my_answer.id is not null),
      'selected_option_id', v_my_answer.selected_option_id,
      'is_revealed', (v_round.status = 'revealed'),
      'is_correct', v_is_correct,
      'points_awarded', v_points,
      'correct_option_id', v_correct_opt_id,
      'explanation', v_explanation
    ),
    'leaderboard', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', rp.nickname,
        'score', rp.score,
        'is_me', (rp.user_id = v_user),
        'is_host', (rp.user_id = v_room.host_id)
      ) order by rp.score desc, rp.joined_at asc)
      from public.room_players rp
      where rp.room_id = p_room_id
    ), '[]'::jsonb)
  );
end;
$$;

-- 12. UPDATE PUBLIC ROOM & ROUND STATE FOR SHARED DISPLAY
create or replace function public.get_public_room_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'room_code', r.code,
    'status', r.status,
    'phase', coalesce(r.phase, r.status),
    'game_mode', r.selected_game,
    'game_title', r.game_title,
    'state_version', r.state_version,
    'round_ends_at', r.round_ends_at,
    'last_transition_at', r.last_transition_at,
    'total_players', (select count(*) from public.room_players rp where rp.room_id = r.id),
    'answered_count', (
      select count(*) from public.player_answers pa
      where pa.round_id = r.current_round_id
    ),
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', rp.nickname,
        'score', rp.score,
        'seat', rp.seat_no,
        'has_answered', exists(
          select 1 from public.player_answers pa
          where pa.round_id = r.current_round_id and pa.player_id = rp.user_id
        )
      ) order by rp.score desc, rp.joined_at asc)
      from public.room_players rp
      where rp.room_id = r.id and rp.role <> 'spectator'
    ), '[]'::jsonb)
  )
  from public.rooms r
  where r.code = upper(trim(p_room_code));
$$;

create or replace function public.get_public_round_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'position', gr.position,
    'game_mode', q.game_mode,
    'duration_seconds', q.duration_seconds,
    'status', gr.status,
    'opens_at', gr.opens_at,
    'closes_at', gr.closes_at,
    'prompt', case
      when q.game_mode = 'who_am_i' then 'Ask the table yes-or-no questions and work out who you are.'
      when q.game_mode = 'guess_image' then 'Study the clue on your phone and make your guess.'
      else q.prompt
    end,
    'media', case
      when q.game_mode in ('who_am_i', 'guess_image') or m.id is null then null
      else jsonb_build_object('type', m.asset_type, 'url', m.public_url, 'alt', m.alt_text)
    end,
    'options', coalesce((
      select jsonb_agg(jsonb_build_object(
        'label', chr(64 + qo.position),
        'text', qo.option_text,
        'is_correct', case when gr.status = 'revealed' then qo.is_correct else null end
      ) order by qo.position)
      from public.question_options qo
      where qo.question_id = q.id
    ), '[]'::jsonb),
    'correct_option', case
      when gr.status = 'revealed' and q.game_mode not in ('who_am_i', 'guess_image') then (
        select qo.option_text from public.question_options qo
        where qo.question_id = q.id and qo.is_correct = true limit 1
      )
      else null
    end,
    'explanation', case
      when gr.status = 'revealed' and q.game_mode not in ('who_am_i', 'guess_image') then q.explanation
      else null
    end
  )
  from public.rooms r
  join public.game_rounds gr on gr.id = r.current_round_id
  join public.questions q on q.id = gr.question_id
  left join public.media_assets m on m.id = q.media_id
  where r.code = upper(trim(p_room_code))
    and r.status = 'playing'
  limit 1;
$$;

-- 13. Grants
grant execute on function public.start_game(uuid, text) to authenticated;
grant execute on function public.submit_game_answer(uuid, uuid) to authenticated;
grant execute on function public.host_reveal_round(uuid) to authenticated;
grant execute on function public.host_advance_round(uuid) to authenticated;
grant execute on function public.host_end_game(uuid) to authenticated;
grant execute on function public.get_player_game_state(uuid) to authenticated;
grant execute on function public.get_public_room_state(text) to authenticated;
grant execute on function public.get_public_round_state(text) to authenticated;
