create table if not exists public.fantasy_settings (
  id text primary key default 'current',
  season text not null default 'Season 05',
  night integer not null default 4,
  deadline timestamptz not null,
  status text not null default 'live',
  updated_at timestamptz not null default now()
);
create table if not exists public.fantasy_managers (
  id uuid primary key references auth.users(id) on delete cascade,
  team_name text not null,
  actual_name text,
  total_points integer not null default 0,
  night_points integer not null default 0,
  overall_rank integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.fantasy_squads (
  id uuid primary key default gen_random_uuid(),
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  tier text not null,
  is_captain boolean not null default false,
  season text not null default 'Season 05',
  night integer not null default 4,
  unique(manager_id, player_id, season, night)
);
create table if not exists public.fantasy_powerup_uses (
  id uuid primary key default gen_random_uuid(),
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  powerup text not null check (powerup in ('diamond','no_negative','wildcard','diamond_boost')),
  season text not null default 'Season 05',
  night integer,
  captain_player_id uuid references public.players(id),
  created_at timestamptz not null default now()
);
create table if not exists public.fantasy_player_scores (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  season text not null default 'Season 05',
  night integer not null,
  game_points numeric not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  overall_points numeric not null default 0,
  updated_at timestamptz not null default now(),
  unique(player_id, season, night)
);
alter table public.fantasy_settings enable row level security;
alter table public.fantasy_managers enable row level security;
alter table public.fantasy_squads enable row level security;
alter table public.fantasy_powerup_uses enable row level security;
alter table public.fantasy_player_scores enable row level security;
create policy "public can read fantasy settings" on public.fantasy_settings for select using (true);
create policy "public can read managers leaderboard" on public.fantasy_managers for select using (true);
create policy "users manage own manager profile" on public.fantasy_managers for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "users manage own squad" on public.fantasy_squads for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
create policy "users read own powerup uses" on public.fantasy_powerup_uses for select using (auth.uid() = manager_id);
create policy "users create own powerup uses" on public.fantasy_powerup_uses for insert with check (auth.uid() = manager_id);
create policy "public can read player scores" on public.fantasy_player_scores for select using (true);
