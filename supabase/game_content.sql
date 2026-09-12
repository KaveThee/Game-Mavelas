-- Game Mavelas content system. Run after supabase/schema.sql.
-- Content is curated through SQL/admin tooling; game clients do not get direct
-- access to answer keys.

create table if not exists public.content_packs (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  title text not null,
  description text,
  region text not null default 'world',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  title text not null,
  icon text,
  sort_order smallint not null default 0,
  is_active boolean not null default true
);

create table if not exists public.question_sources (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  title text not null,
  source_url text,
  licence text,
  notes text,
  checked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  asset_type text not null check (asset_type in ('flag', 'image', 'audio')),
  provider text not null,
  asset_key text not null,
  public_url text,
  alt_text text not null,
  attribution text,
  licence text,
  source_id uuid references public.question_sources(id) on delete set null,
  width integer,
  height integer,
  created_at timestamptz not null default now(),
  unique (provider, asset_key)
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9_]+$'),
  pack_id uuid not null references public.content_packs(id) on delete restrict,
  category_id uuid not null references public.categories(id) on delete restrict,
  game_mode text not null check (game_mode in ('trivia', 'flag_frenzy', 'who_am_i', 'guess_image')),
  prompt text not null check (char_length(prompt) between 5 and 500),
  explanation text,
  media_id uuid references public.media_assets(id) on delete set null,
  difficulty smallint not null default 2 check (difficulty between 1 and 5),
  duration_seconds smallint not null default 20 check (duration_seconds between 5 and 120),
  base_points smallint not null default 100 check (base_points between 10 and 1000),
  locale text not null default 'en-KE',
  tags text[] not null default '{}',
  status text not null default 'draft' check (status in ('draft', 'review', 'approved', 'retired')),
  source_id uuid references public.question_sources(id) on delete set null,
  fact_checked_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- This table deliberately has no client SELECT grant. A future server route
-- returns shuffled choices without exposing the is_correct key.
create table if not exists public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  position smallint not null check (position between 1 and 6),
  option_text text not null check (char_length(option_text) between 1 and 240),
  is_correct boolean not null default false,
  unique (question_id, position),
  unique (question_id, option_text)
);

create table if not exists public.round_templates (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  title text not null,
  game_mode text not null check (game_mode in ('trivia', 'flag_frenzy', 'who_am_i', 'guess_image')),
  description text,
  is_active boolean not null default true
);

create table if not exists public.round_template_steps (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.round_templates(id) on delete cascade,
  position smallint not null check (position between 1 and 12),
  category_id uuid references public.categories(id) on delete set null,
  difficulty_min smallint not null default 1 check (difficulty_min between 1 and 5),
  difficulty_max smallint not null default 5 check (difficulty_max between 1 and 5),
  question_count smallint not null check (question_count between 1 and 30),
  seconds_per_question smallint not null check (seconds_per_question between 5 and 120),
  unique (template_id, position),
  check (difficulty_min <= difficulty_max)
);

create table if not exists public.game_rounds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  template_id uuid references public.round_templates(id) on delete set null,
  question_id uuid references public.questions(id) on delete set null,
  position smallint not null,
  status text not null default 'pending' check (status in ('pending', 'open', 'closed', 'revealed')),
  opens_at timestamptz,
  closes_at timestamptz,
  created_at timestamptz not null default now(),
  unique (room_id, position)
);

create table if not exists public.player_answers (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  player_id uuid not null,
  selected_option_id uuid references public.question_options(id) on delete set null,
  free_text_answer text,
  is_correct boolean,
  points_awarded integer not null default 0,
  answered_at timestamptz not null default now(),
  unique (round_id, player_id),
  check (selected_option_id is not null or free_text_answer is not null)
);

create index if not exists questions_playable_idx
  on public.questions (game_mode, status, difficulty, category_id)
  where status = 'approved';
create index if not exists questions_pack_idx on public.questions (pack_id, status);
create index if not exists question_options_question_idx on public.question_options (question_id, position);
create index if not exists game_rounds_room_idx on public.game_rounds (room_id, position);
create index if not exists player_answers_round_idx on public.player_answers (round_id, player_id);
create index if not exists room_players_room_user_idx on public.room_players (room_id, user_id);

alter table public.content_packs enable row level security;
alter table public.categories enable row level security;
alter table public.question_sources enable row level security;
alter table public.media_assets enable row level security;
alter table public.questions enable row level security;
alter table public.question_options enable row level security;
alter table public.round_templates enable row level security;
alter table public.round_template_steps enable row level security;
alter table public.game_rounds enable row level security;
alter table public.player_answers enable row level security;

revoke all on public.content_packs, public.categories, public.question_sources,
  public.media_assets, public.questions, public.question_options,
  public.round_templates, public.round_template_steps, public.game_rounds,
  public.player_answers from anon, authenticated;

-- Content remains server/admin only until the secure question-delivery route is added.
-- Players can only read game activity for rooms they joined.
grant select on public.game_rounds to authenticated;
grant select on public.player_answers to authenticated;

create policy "room members read rounds" on public.game_rounds for select to authenticated
  using (exists (
    select 1 from public.room_players rp
    where rp.room_id = game_rounds.room_id and rp.user_id = (select auth.uid())
  ));

create policy "room members read answers" on public.player_answers for select to authenticated
  using (exists (
    select 1 from public.room_players rp
    where rp.room_id = player_answers.room_id and rp.user_id = (select auth.uid())
  ));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_rounds'
  ) then
    alter publication supabase_realtime add table public.game_rounds;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'player_answers'
  ) then
    alter publication supabase_realtime add table public.player_answers;
  end if;
end $$;
