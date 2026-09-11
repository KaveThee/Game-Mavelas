-- Run this once in Supabase: SQL Editor -> New query.
create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9]{4,6}$'),
  host_id uuid not null,
  selected_game text not null default 'who_am_i',
  status text not null default 'lobby' check (status in ('lobby','playing','results','closed')),
  state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.room_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null,
  nickname text not null check (char_length(nickname) between 2 and 24),
  score integer not null default 0,
  joined_at timestamptz not null default now(),
  unique (room_id, user_id)
);

alter table public.rooms enable row level security;
alter table public.room_players enable row level security;

create policy "players can read rooms" on public.rooms for select to authenticated using (true);
create policy "players can create rooms" on public.rooms for insert to authenticated with check (auth.uid() = host_id);
create policy "host updates room" on public.rooms for update to authenticated using (auth.uid() = host_id) with check (auth.uid() = host_id);
create policy "players can read room members" on public.room_players for select to authenticated using (true);
create policy "players join rooms as themselves" on public.room_players for insert to authenticated with check (auth.uid() = user_id);
create policy "players update their own score" on public.room_players for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.room_players;
