-- Phase 2 private action foundation.
--
-- These tables are intentionally kept outside the exposed public schema. The
-- four Phase 2 games remain unavailable until their write RPCs, controllers,
-- displays, and multi-device recovery tests are complete.

create table private.phase2_sessions (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  game_mode text not null check (game_mode in (
    'meme_factory',
    'bluff_draw',
    'word_sabotage',
    'word_search_race'
  )),
  phase text not null default 'prepared' check (phase in (
    'prepared',
    'drawing',
    'submitting',
    'bluffing',
    'voting',
    'playing',
    'results',
    'finished'
  )),
  round_number smallint not null default 1 check (round_number between 1 and 20),
  public_state jsonb not null default '{}'::jsonb,
  secret_state jsonb not null default '{}'::jsonb,
  state_version bigint not null default 0 check (state_version >= 0),
  opens_at timestamptz,
  closes_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(public_state) = 'object'),
  check (jsonb_typeof(secret_state) = 'object')
);

create table private.phase2_submissions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references private.phase2_sessions(room_id) on delete cascade,
  round_number smallint not null check (round_number between 1 and 20),
  author_id uuid not null,
  submission_kind text not null check (submission_kind in ('caption', 'bluff', 'drawing')),
  payload jsonb not null,
  created_at timestamptz not null default now(),
  foreign key (room_id, author_id)
    references public.room_players(room_id, user_id)
    on delete cascade,
  unique (room_id, round_number, author_id, submission_kind),
  check (jsonb_typeof(payload) = 'object'),
  check (pg_column_size(payload) <= 32768)
);

create table private.phase2_votes (
  room_id uuid not null references private.phase2_sessions(room_id) on delete cascade,
  round_number smallint not null check (round_number between 1 and 20),
  voter_id uuid not null,
  submission_id uuid not null references private.phase2_submissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room_id, round_number, voter_id),
  foreign key (room_id, voter_id)
    references public.room_players(room_id, user_id)
    on delete cascade
);

create table private.phase2_word_claims (
  room_id uuid not null references private.phase2_sessions(room_id) on delete cascade,
  round_number smallint not null check (round_number between 1 and 20),
  word text not null check (word ~ '^[A-Z]{3,24}$'),
  player_id uuid not null,
  path jsonb not null,
  points smallint not null check (points between 0 and 100),
  created_at timestamptz not null default now(),
  primary key (room_id, round_number, word),
  foreign key (room_id, player_id)
    references public.room_players(room_id, user_id)
    on delete cascade,
  check (jsonb_typeof(path) = 'array'),
  check (jsonb_array_length(path) between 3 and 24)
);

create table private.phase2_action_ledger (
  room_id uuid not null references private.phase2_sessions(room_id) on delete cascade,
  action_id uuid not null,
  player_id uuid not null,
  client_sequence bigint not null check (client_sequence > 0),
  action_kind text not null check (char_length(action_kind) between 1 and 40),
  created_at timestamptz not null default now(),
  primary key (room_id, action_id),
  unique (room_id, player_id, client_sequence),
  foreign key (room_id, player_id)
    references public.room_players(room_id, user_id)
    on delete cascade
);

create index phase2_submissions_round_idx
  on private.phase2_submissions (room_id, round_number, submission_kind);

create index phase2_votes_submission_idx
  on private.phase2_votes (submission_id);

create index phase2_word_claims_player_idx
  on private.phase2_word_claims (room_id, player_id, round_number);

create index phase2_action_ledger_rate_idx
  on private.phase2_action_ledger (room_id, player_id, created_at desc);

alter table private.phase2_sessions enable row level security;
alter table private.phase2_submissions enable row level security;
alter table private.phase2_votes enable row level security;
alter table private.phase2_word_claims enable row level security;
alter table private.phase2_action_ledger enable row level security;

revoke all on table private.phase2_sessions from public, anon, authenticated;
revoke all on table private.phase2_submissions from public, anon, authenticated;
revoke all on table private.phase2_votes from public, anon, authenticated;
revoke all on table private.phase2_word_claims from public, anon, authenticated;
revoke all on table private.phase2_action_ledger from public, anon, authenticated;

create or replace function private.claim_phase2_action(
  p_room_id uuid,
  p_action_id uuid,
  p_client_sequence bigint,
  p_action_kind text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_previous_sequence bigint;
  v_recent_actions integer;
begin
  if v_user is null or not exists (
    select 1
    from public.room_players
    where room_id = p_room_id
      and user_id = v_user
      and role in ('host', 'player')
  ) then
    raise exception 'You are not an active player in this room';
  end if;

  if p_action_id is null or p_client_sequence <= 0 or char_length(p_action_kind) not between 1 and 40 then
    raise exception 'Invalid Phase 2 action envelope';
  end if;

  select coalesce(max(client_sequence), 0)
  into v_previous_sequence
  from private.phase2_action_ledger
  where room_id = p_room_id and player_id = v_user;

  if p_client_sequence <> v_previous_sequence + 1 then
    raise exception 'Action sequence must be exactly %', v_previous_sequence + 1;
  end if;

  select count(*)
  into v_recent_actions
  from private.phase2_action_ledger
  where room_id = p_room_id
    and player_id = v_user
    and created_at >= now() - interval '10 seconds';

  if v_recent_actions >= 12 then
    raise exception 'Too many actions; wait before trying again';
  end if;

  insert into private.phase2_action_ledger
    (room_id, action_id, player_id, client_sequence, action_kind)
  values
    (p_room_id, p_action_id, v_user, p_client_sequence, p_action_kind);
exception
  when unique_violation then
    raise exception 'Action was already processed';
end;
$$;

create or replace function public.get_public_phase2_state(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_user uuid := auth.uid();
  v_room public.rooms%rowtype;
  v_session private.phase2_sessions%rowtype;
begin
  if v_user is null then raise exception 'Sign in required'; end if;

  select * into v_room
  from public.rooms
  where code = upper(btrim(p_room_code));

  if not found or not exists (
    select 1 from public.room_players
    where room_id = v_room.id and user_id = v_user
  ) then
    raise exception 'Room not found';
  end if;

  select * into v_session
  from private.phase2_sessions
  where room_id = v_room.id;

  if not found then raise exception 'Phase 2 session not found'; end if;

  return jsonb_build_object(
    'room_id', v_room.id,
    'room_code', v_room.code,
    'game_mode', v_session.game_mode,
    'phase', v_session.phase,
    'round_number', v_session.round_number,
    'state_version', v_session.state_version,
    'opens_at', v_session.opens_at,
    'closes_at', v_session.closes_at,
    'state', v_session.public_state,
    'players', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', rp.id,
        'name', rp.nickname,
        'score', rp.score,
        'role', rp.role
      ) order by rp.score desc, rp.joined_at), '[]'::jsonb)
      from public.room_players rp
      where rp.room_id = v_room.id and rp.role in ('host', 'player')
    )
  );
end;
$$;

create or replace function public.get_phase2_player_state(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
stable
as $$
declare
  v_user uuid := auth.uid();
  v_session private.phase2_sessions%rowtype;
begin
  if v_user is null or not exists (
    select 1 from public.room_players
    where room_id = p_room_id
      and user_id = v_user
      and role in ('host', 'player')
  ) then
    raise exception 'You are not an active player in this room';
  end if;

  select * into v_session
  from private.phase2_sessions
  where room_id = p_room_id;

  if not found then raise exception 'Phase 2 session not found'; end if;

  return jsonb_build_object(
    'room_id', p_room_id,
    'game_mode', v_session.game_mode,
    'phase', v_session.phase,
    'round_number', v_session.round_number,
    'state_version', v_session.state_version,
    'private_prompt', v_session.secret_state #>> array['player_prompts', v_user::text],
    'submission', (
      select submission.payload
      from private.phase2_submissions submission
      where submission.room_id = p_room_id
        and submission.round_number = v_session.round_number
        and submission.author_id = v_user
      order by submission.created_at desc
      limit 1
    ),
    'has_voted', exists (
      select 1 from private.phase2_votes vote
      where vote.room_id = p_room_id
        and vote.round_number = v_session.round_number
        and vote.voter_id = v_user
    ),
    'claimed_words', (
      select coalesce(jsonb_agg(claim.word order by claim.created_at), '[]'::jsonb)
      from private.phase2_word_claims claim
      where claim.room_id = p_room_id
        and claim.round_number = v_session.round_number
        and claim.player_id = v_user
    )
  );
end;
$$;

revoke all on function private.claim_phase2_action(uuid, uuid, bigint, text) from public, anon, authenticated;
revoke all on function public.get_public_phase2_state(text) from public, anon;
revoke all on function public.get_phase2_player_state(uuid) from public, anon;
grant execute on function public.get_public_phase2_state(text) to authenticated;
grant execute on function public.get_phase2_player_state(uuid) to authenticated;
