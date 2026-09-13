-- Game Mavelas shared-screen core.
-- Run after schema.sql, game_content.sql and game_engine.sql.
-- This adds the universal room skeleton without exposing answer keys or secrets.

alter table public.rooms
  add column if not exists phase text not null default 'lobby'
    check (phase in ('lobby', 'selected', 'playing', 'revealed', 'results', 'closed')),
  add column if not exists game_title text,
  add column if not exists max_players smallint not null default 12
    check (max_players between 2 and 100),
  add column if not exists current_round_id uuid,
  add column if not exists state_version bigint not null default 0,
  add column if not exists last_transition_at timestamptz not null default now();

alter table public.room_players
  add column if not exists role text not null default 'player'
    check (role in ('host', 'player', 'moderator', 'jury', 'spectator')),
  add column if not exists seat_no smallint,
  add column if not exists is_connected boolean not null default true,
  add column if not exists last_seen_at timestamptz not null default now();

create table if not exists public.room_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sequence bigint not null,
  actor_id uuid,
  event_type text not null check (event_type ~ '^[a-z0-9_]+$'),
  public_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (room_id, sequence)
);

create table if not exists public.room_player_private_state (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  player_id uuid not null,
  round_id uuid references public.game_rounds(id) on delete cascade,
  state_key text not null check (state_key ~ '^[a-z0-9_]+$'),
  private_payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (room_id, player_id, round_id, state_key)
);

create table if not exists public.score_ledger (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_id uuid references public.game_rounds(id) on delete set null,
  player_id uuid not null,
  points_delta integer not null,
  reason text not null check (reason ~ '^[a-z0-9_]+$'),
  created_at timestamptz not null default now()
);

create index if not exists room_events_room_sequence_idx
  on public.room_events (room_id, sequence);
create index if not exists room_private_state_lookup_idx
  on public.room_player_private_state (room_id, player_id, round_id);
create index if not exists score_ledger_room_player_idx
  on public.score_ledger (room_id, player_id, created_at);

alter table public.room_events enable row level security;
alter table public.room_player_private_state enable row level security;
alter table public.score_ledger enable row level security;

revoke all on public.room_events, public.room_player_private_state, public.score_ledger
  from anon, authenticated;

-- The display receives only this explicitly built payload. It cannot read
-- questions, answer options, answer keys, identities, or private state.
create or replace function public.get_public_room_state(p_room_code text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'room_code', r.code,
    'status', r.status,
    'phase', r.phase,
    'game_mode', r.selected_game,
    'game_title', r.game_title,
    'state_version', r.state_version,
    'last_transition_at', r.last_transition_at,
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', rp.nickname,
        'score', rp.score,
        'seat', rp.seat_no
      ) order by rp.score desc, rp.joined_at asc)
      from public.room_players rp
      where rp.room_id = r.id and rp.role <> 'spectator'
    ), '[]'::jsonb)
  )
  from public.rooms r
  where r.code = upper(trim(p_room_code));
$$;

revoke all on function public.get_public_room_state(text) from public, anon;
grant execute on function public.get_public_room_state(text) to authenticated;

-- A second, game-aware allowlist for the projector. "Who Am I?" and
-- "Guess the Image" intentionally receive no question media or secret prompt.
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
    'prompt', case
      when q.game_mode = 'who_am_i' then 'Ask the table yes-or-no questions and work out who you are.'
      when q.game_mode = 'guess_image' then 'Study the clue on your phone and make your guess.'
      else q.prompt
    end,
    'media', case
      when q.game_mode in ('who_am_i', 'guess_image') or m.id is null then null
      else jsonb_build_object('type', m.asset_type, 'url', m.public_url, 'alt', m.alt_text)
    end
  )
  from public.rooms r
  join public.game_rounds gr on gr.room_id = r.id and gr.status = 'open'
  join public.questions q on q.id = gr.question_id
  left join public.media_assets m on m.id = q.media_id
  where r.code = upper(trim(p_room_code))
    and r.status = 'playing'
  order by gr.position
  limit 1;
$$;

revoke all on function public.get_public_round_state(text) from public, anon;
grant execute on function public.get_public_round_state(text) to authenticated;

-- Realtime clients listen only to safe room/event summaries. Private state and
-- score ledger remain server-only.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_events'
  ) then
    alter publication supabase_realtime add table public.room_events;
  end if;
end $$;
