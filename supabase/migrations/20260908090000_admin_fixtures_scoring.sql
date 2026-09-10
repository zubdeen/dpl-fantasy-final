-- Ensure the storefront can read the current deadline while RLS is enabled.
grant select on public.fantasy_settings to anon, authenticated;
grant select on public.players to anon, authenticated;
grant select on public.fantasy_player_scores to anon, authenticated;
grant select on public.fantasy_managers to anon, authenticated;

drop policy if exists "public can read fantasy settings" on public.fantasy_settings;
create policy "public can read fantasy settings" on public.fantasy_settings for select to anon, authenticated using (true);

create table if not exists public.fantasy_game_nights (
  id uuid primary key default gen_random_uuid(),
  season text not null default 'Season 05',
  night integer not null,
  deadline timestamptz not null,
  status text not null default 'upcoming' check (status in ('upcoming','live','locked','complete')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(season, night)
);
alter table public.fantasy_game_nights enable row level security;
grant select on public.fantasy_game_nights to anon, authenticated;
drop policy if exists "public can read game nights" on public.fantasy_game_nights;
create policy "public can read game nights" on public.fantasy_game_nights for select to anon, authenticated using (true);

create table if not exists public.fantasy_fixtures (
  id uuid primary key default gen_random_uuid(),
  season text not null default 'Season 05',
  night integer not null,
  fixture_type text not null default 'regular' check (fixture_type in ('regular','eliminator')),
  home_team text not null,
  away_team text not null,
  home_score integer,
  away_score integer,
  home_handicap integer not null default 0,
  away_handicap integer not null default 0,
  status text not null default 'scheduled' check (status in ('scheduled','live','complete')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.fantasy_fixtures enable row level security;
grant select on public.fantasy_fixtures to anon, authenticated;
drop policy if exists "public can read fixtures" on public.fantasy_fixtures;
create policy "public can read fixtures" on public.fantasy_fixtures for select to anon, authenticated using (true);

create table if not exists public.fantasy_fixture_player_points (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.fantasy_fixtures(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  game_difference numeric not null default 0,
  handicap_adjustment numeric not null default 0,
  calculated_points numeric not null default 0,
  season text not null default 'Season 05',
  night integer not null,
  unique(fixture_id, player_id)
);
alter table public.fantasy_fixture_player_points enable row level security;
grant select on public.fantasy_fixture_player_points to anon, authenticated;
drop policy if exists "public can read fixture player points" on public.fantasy_fixture_player_points;
create policy "public can read fixture player points" on public.fantasy_fixture_player_points for select to anon, authenticated using (true);

-- Regular: (games won - games lost) / matches is represented by game_difference.
-- Eliminator: adjusted difference = raw game_difference + team handicap difference.
create or replace function public.eliminator_adjusted_points(raw_difference numeric, player_handicap integer, opposing_handicap integer)
returns numeric language sql immutable as $$
  select raw_difference + (player_handicap - opposing_handicap);
$$;
