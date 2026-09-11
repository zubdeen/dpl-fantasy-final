create extension if not exists "uuid-ossp";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  team_name text,
  display_name text,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now()
);
create table if not exists public.clubs (id uuid primary key default uuid_generate_v4(), name text not null unique, short_name text not null, created_at timestamptz not null default now());
create table if not exists public.players (id uuid primary key default uuid_generate_v4(), name text not null, initials text not null, tier text not null check (tier in ('M1','M2','STAR','CORE','DEV')), club_id uuid references public.clubs(id), price integer not null, form integer not null default 0, active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.gameweeks (id uuid primary key default uuid_generate_v4(), name text not null, lock_at timestamptz not null, unlock_at timestamptz, status text not null default 'upcoming' check (status in ('upcoming','live','complete')));
create table if not exists public.fixtures (id uuid primary key default uuid_generate_v4(), gameweek_id uuid references public.gameweeks(id), home_club_id uuid references public.clubs(id), away_club_id uuid references public.clubs(id), starts_at timestamptz not null, home_score integer, away_score integer, status text not null default 'scheduled');
create table if not exists public.fantasy_fixtures (
  id uuid primary key default uuid_generate_v4(),
  season text not null,
  night integer not null,
  fixture_type text not null default 'regular',
  home_team text not null,
  away_team text not null,
  home_player_1_id uuid references public.players(id),
  home_player_2_id uuid references public.players(id),
  away_player_1_id uuid references public.players(id),
  away_player_2_id uuid references public.players(id),
  home_score integer,
  away_score integer,
  tie_breaker boolean not null default false,
  played_at timestamptz,
  home_handicap integer not null default 0,
  away_handicap integer not null default 0,
  status text not null default 'scheduled',
  created_at timestamptz not null default now()
);
create table if not exists public.squads (id uuid primary key default uuid_generate_v4(), user_id uuid not null references auth.users(id) on delete cascade, team_name text not null, budget integer not null default 3400, captain_id uuid references public.players(id), diamond_active boolean not null default false, wildcard_used boolean not null default false, safety_net_used boolean not null default false, diamond_boost_used boolean not null default false, updated_at timestamptz not null default now(), unique(user_id));
create table if not exists public.squad_players (squad_id uuid references public.squads(id) on delete cascade, player_id uuid references public.players(id), on_court boolean not null default false, primary key (squad_id, player_id));

create table if not exists public.fantasy_managers (
  id uuid primary key references auth.users(id) on delete cascade,
  team_name text,
  display_name text,
  dpl_team text,
  team_locked boolean not null default false,
  locked_at timestamptz,
  transfers_used integer not null default 0,
  transfer_period integer not null default 1,
  wildcard_used boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.fantasy_squads (
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  player_id uuid not null references public.players(id),
  season text not null,
  night integer not null default 1,
  tier text not null check (tier in ('M1','M2','STAR','CORE','DEV')),
  slot integer not null default 0,
  is_captain boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (manager_id, player_id, season)
);
create table if not exists public.fantasy_manager_lineups (
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  player_id uuid not null references public.players(id),
  season text not null,
  period integer not null,
  locked_at timestamptz not null default now(),
  primary key (manager_id, player_id, season, period)
);
create table if not exists public.fantasy_manager_player_scores (
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  player_id uuid not null references public.players(id),
  season text not null,
  gameweek integer not null,
  points integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (manager_id, player_id, season, gameweek)
);
create table if not exists public.fantasy_manager_gameweek_scores (
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  season text not null,
  gameweek integer not null,
  points integer not null default 0,
  overall_points integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (manager_id, season, gameweek)
);
create table if not exists public.fantasy_settings (
  id text primary key,
  season text not null,
  night integer not null default 1,
  gameweek integer not null default 1,
  deadline timestamptz not null,
  lock_at timestamptz,
  unlock_at timestamptz,
  status text not null default 'active' check (status in ('active','complete'))
);
create table if not exists public.fantasy_game_nights (
  season text not null,
  night integer not null,
  deadline timestamptz not null,
  lock_at timestamptz,
  unlock_at timestamptz,
  status text not null default 'active' check (status in ('active','complete')),
  primary key (season, night)
);
-- Current-night player display scores are reset when a new active night is selected. Historical manager totals remain in fantasy_manager_gameweek_scores and fantasy_manager_player_scores.
create table if not exists public.fantasy_player_scores (
  player_id uuid not null references public.players(id) on delete cascade,
  season text not null,
  night integer not null,
  game_points integer not null default 0,
  overall_points integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (player_id, season, night)
);
create table if not exists public.fantasy_fixture_player_points (
  id uuid primary key default uuid_generate_v4(),
  fixture_id uuid,
  player_id uuid not null references public.players(id) on delete cascade,
  season text not null,
  night integer not null,
  game_difference integer not null default 0,
  handicap_adjustment integer not null default 0,
  calculated_points integer not null default 0,
  created_at timestamptz not null default now(),
  unique(fixture_id, player_id)
);
create table if not exists public.fantasy_transfer_events (
  id uuid primary key default uuid_generate_v4(),
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  season text not null,
  period integer not null,
  from_player_id uuid not null references public.players(id),
  to_player_id uuid not null references public.players(id),
  created_at timestamptz not null default now()
);
create table if not exists public.fantasy_powerup_uses (
  id uuid primary key default uuid_generate_v4(),
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  powerup text not null check (powerup in ('diamond','no_negative','wildcard','diamond_boost')),
  season text not null,
  night integer not null,
  captain_player_id uuid references public.players(id),
  created_at timestamptz not null default now(),
  unique(manager_id, powerup, season, night)
);

-- The live admin/storefront code reads these legacy-compatible player fields.
alter table public.players add column if not exists category text;
alter table public.players add column if not exists team text;
alter table public.players add column if not exists team_name text;
alter table public.players add column if not exists profile_picture text;
alter table public.players add column if not exists team_logo text;
alter table public.players add column if not exists cost integer;

-- Safe upgrades for databases created from the earlier prototype schema.
alter table public.profiles add column if not exists team_name text;
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists role text not null default 'user';
alter table public.fantasy_managers add column if not exists team_name text;
alter table public.fantasy_managers add column if not exists display_name text;
alter table public.fantasy_managers add column if not exists dpl_team text;
alter table public.fantasy_managers add column if not exists created_at timestamptz not null default now();
alter table public.fantasy_managers add column if not exists updated_at timestamptz not null default now();
alter table public.fantasy_managers add column if not exists team_locked boolean not null default false;
alter table public.fantasy_managers add column if not exists locked_at timestamptz;
alter table public.fantasy_managers add column if not exists transfers_used integer not null default 0;
alter table public.fantasy_managers add column if not exists transfer_period integer not null default 1;
alter table public.fantasy_managers add column if not exists wildcard_used boolean not null default false;
alter table public.fantasy_squads add column if not exists slot integer not null default 0;
alter table public.fantasy_player_scores add column if not exists wins integer not null default 0;
alter table public.fantasy_player_scores add column if not exists losses integer not null default 0;
alter table public.fantasy_settings add column if not exists gameweek integer not null default 1;
alter table public.gameweeks add column if not exists unlock_at timestamptz;
alter table public.fantasy_settings add column if not exists lock_at timestamptz;
alter table public.fantasy_settings add column if not exists unlock_at timestamptz;
alter table public.fantasy_game_nights add column if not exists lock_at timestamptz;
alter table public.fantasy_game_nights add column if not exists unlock_at timestamptz;
create unique index if not exists fantasy_fixture_player_points_fixture_player_unique on public.fantasy_fixture_player_points (fixture_id, player_id);
alter table public.fantasy_fixtures add column if not exists home_player_1_id uuid;
alter table public.fantasy_fixtures add column if not exists home_player_2_id uuid;
alter table public.fantasy_fixtures add column if not exists away_player_1_id uuid;
alter table public.fantasy_fixtures add column if not exists away_player_2_id uuid;
alter table public.fantasy_fixtures add column if not exists tie_breaker boolean not null default false;
alter table public.fantasy_fixtures add column if not exists played_at timestamptz;

alter table public.profiles enable row level security;
alter table public.squads enable row level security;
alter table public.squad_players enable row level security;
alter table public.fantasy_managers enable row level security;
alter table public.fantasy_squads enable row level security;
alter table public.fantasy_manager_lineups enable row level security;
alter table public.fantasy_manager_player_scores enable row level security;
alter table public.fantasy_manager_gameweek_scores enable row level security;
alter table public.fantasy_transfer_events enable row level security;
alter table public.fantasy_powerup_uses enable row level security;
alter table public.players enable row level security;
alter table public.clubs enable row level security;
alter table public.fixtures enable row level security;
alter table public.gameweeks enable row level security;
alter table public.fantasy_player_scores enable row level security;
alter table public.fantasy_fixture_player_points enable row level security;
alter table public.fantasy_settings enable row level security;
alter table public.fantasy_game_nights enable row level security;
alter table public.fantasy_fixtures enable row level security;

-- Policies are intentionally explicit: managers can mutate only their own team,
-- while leaderboard and scoring reads are public to signed-in league members.
drop policy if exists "profiles own record" on public.profiles;
create policy "profiles own record" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists "authenticated profiles read" on public.profiles;
create policy "authenticated profiles read" on public.profiles for select to authenticated using (auth.uid() is not null);
drop policy if exists "fantasy managers own record" on public.fantasy_managers;
create policy "fantasy managers own record" on public.fantasy_managers for all using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists "fantasy managers leaderboard read" on public.fantasy_managers;
create policy "fantasy managers leaderboard read" on public.fantasy_managers for select using (true);
drop policy if exists "fantasy squads own record" on public.fantasy_squads;
create policy "fantasy squads own record" on public.fantasy_squads for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
drop policy if exists "fantasy squads leaderboard read" on public.fantasy_squads;
create policy "fantasy squads leaderboard read" on public.fantasy_squads for select using (true);
drop policy if exists "fantasy manager lineups own record" on public.fantasy_manager_lineups;
create policy "fantasy manager lineups own record" on public.fantasy_manager_lineups for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
drop policy if exists "fantasy manager lineups scoring read" on public.fantasy_manager_lineups;
create policy "fantasy manager lineups scoring read" on public.fantasy_manager_lineups for select using (true);
drop policy if exists "fantasy manager player scores own record" on public.fantasy_manager_player_scores;
create policy "fantasy manager player scores own record" on public.fantasy_manager_player_scores for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
drop policy if exists "fantasy manager player scores leaderboard read" on public.fantasy_manager_player_scores;
create policy "fantasy manager player scores leaderboard read" on public.fantasy_manager_player_scores for select using (true);
drop policy if exists "authenticated manage fantasy manager player scores" on public.fantasy_manager_player_scores;
create policy "authenticated manage fantasy manager player scores" on public.fantasy_manager_player_scores for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "fantasy manager gameweek scores own record" on public.fantasy_manager_gameweek_scores;
create policy "fantasy manager gameweek scores own record" on public.fantasy_manager_gameweek_scores for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
drop policy if exists "fantasy manager gameweek scores leaderboard read" on public.fantasy_manager_gameweek_scores;
create policy "fantasy manager gameweek scores leaderboard read" on public.fantasy_manager_gameweek_scores for select using (true);
drop policy if exists "authenticated manage fantasy manager gameweek scores" on public.fantasy_manager_gameweek_scores;
create policy "authenticated manage fantasy manager gameweek scores" on public.fantasy_manager_gameweek_scores for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "fantasy transfer events own record" on public.fantasy_transfer_events;
create policy "fantasy transfer events own record" on public.fantasy_transfer_events for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
drop policy if exists "fantasy powerup uses own record" on public.fantasy_powerup_uses;
create policy "fantasy powerup uses own record" on public.fantasy_powerup_uses for all using (auth.uid() = manager_id) with check (auth.uid() = manager_id);
drop policy if exists "authenticated read fantasy powerup uses" on public.fantasy_powerup_uses;
create policy "authenticated read fantasy powerup uses" on public.fantasy_powerup_uses for select to authenticated using (auth.uid() is not null);
drop policy if exists "public active players" on public.players;
create policy "public active players" on public.players for select using (active = true);
drop policy if exists "authenticated read all players" on public.players;
create policy "authenticated read all players" on public.players for select to authenticated using (auth.uid() is not null);
drop policy if exists "authenticated manage players" on public.players;
create policy "authenticated manage players" on public.players for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
insert into storage.buckets (id, name, public)
values ('player-profiles', 'player-profiles', true)
on conflict (id) do update set public = excluded.public;
drop policy if exists "authenticated upload player profiles" on storage.objects;
create policy "authenticated upload player profiles" on storage.objects for insert to authenticated with check (bucket_id = 'player-profiles' and auth.uid() is not null);
drop policy if exists "authenticated update player profiles" on storage.objects;
create policy "authenticated update player profiles" on storage.objects for update to authenticated using (bucket_id = 'player-profiles' and auth.uid() is not null) with check (bucket_id = 'player-profiles' and auth.uid() is not null);
drop policy if exists "public read player profiles" on storage.objects;
create policy "public read player profiles" on storage.objects for select using (bucket_id = 'player-profiles');
drop policy if exists "public clubs" on public.clubs;
create policy "public clubs" on public.clubs for select using (true);
drop policy if exists "public fixtures" on public.fixtures;
create policy "public fixtures" on public.fixtures for select using (true);
drop policy if exists "public fantasy fixtures" on public.fantasy_fixtures;
create policy "public fantasy fixtures" on public.fantasy_fixtures for select using (true);
drop policy if exists "public gameweeks" on public.gameweeks;
create policy "public gameweeks" on public.gameweeks for select using (true);
drop policy if exists "public fantasy player scores" on public.fantasy_player_scores;
create policy "public fantasy player scores" on public.fantasy_player_scores for select using (true);
drop policy if exists "authenticated manage fantasy player scores" on public.fantasy_player_scores;
create policy "authenticated manage fantasy player scores" on public.fantasy_player_scores for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "public fantasy settings" on public.fantasy_settings;
create policy "public fantasy settings" on public.fantasy_settings for select using (true);
drop policy if exists "authenticated manage fantasy settings" on public.fantasy_settings;
create policy "authenticated manage fantasy settings" on public.fantasy_settings for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "public fantasy game nights" on public.fantasy_game_nights;
create policy "public fantasy game nights" on public.fantasy_game_nights for select using (true);
drop policy if exists "authenticated manage fantasy game nights" on public.fantasy_game_nights;
create policy "authenticated manage fantasy game nights" on public.fantasy_game_nights for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "authenticated manage fantasy fixtures" on public.fantasy_fixtures;
create policy "authenticated manage fantasy fixtures" on public.fantasy_fixtures for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "authenticated manage fixture points" on public.fantasy_fixture_player_points;
create policy "authenticated manage fixture points" on public.fantasy_fixture_player_points for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);

-- Keep one profile row for every Supabase Auth user so admin can list sign-ups.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, team_name, display_name)
  values (new.id, nullif(new.raw_user_meta_data->>'team_name', ''), nullif(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'display_name'), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();
insert into public.profiles (id, team_name, display_name)
select u.id, nullif(u.raw_user_meta_data->>'team_name', ''), nullif(coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'display_name'), '')
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
-- Harden fantasy state transitions: direct REST writes cannot bypass lock windows or transfer limits.

create or replace function public.fantasy_period_is_open(p_period integer default null)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.fantasy_settings s
    where s.id = 'current'
      and coalesce(p_period, s.gameweek) = s.gameweek
      and s.unlock_at is not null
      and now() >= s.unlock_at
  );
$$;

create or replace function public.fantasy_internal_write()
returns boolean
language sql stable
as $$
  select coalesce(current_setting('fantasy.internal_write', true), '') = 'on';
$$;

create or replace function public.guard_fantasy_manager_state()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not public.fantasy_internal_write() and tg_op = 'UPDATE' then
    if new.team_locked is distinct from old.team_locked
      or new.locked_at is distinct from old.locked_at
      or new.transfers_used is distinct from old.transfers_used
      or new.transfer_period is distinct from old.transfer_period
      or new.wildcard_used is distinct from old.wildcard_used then
      raise exception 'Fantasy manager state can only be changed by the fantasy rules engine';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists guard_fantasy_manager_state on public.fantasy_managers;
create trigger guard_fantasy_manager_state before update on public.fantasy_managers
for each row execute function public.guard_fantasy_manager_state();

create or replace function public.guard_fantasy_squad_write()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not public.fantasy_internal_write() then
    raise exception 'Fantasy squads can only be changed by the fantasy rules engine';
  end if;
  return coalesce(new, old);
end;
$$;
drop trigger if exists guard_fantasy_squad_write on public.fantasy_squads;
create trigger guard_fantasy_squad_write before insert or update or delete on public.fantasy_squads
for each row execute function public.guard_fantasy_squad_write();

create or replace function public.guard_fantasy_transfer_write()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not public.fantasy_internal_write() then
    raise exception 'Transfer events can only be created by the fantasy rules engine';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_fantasy_transfer_write on public.fantasy_transfer_events;
create trigger guard_fantasy_transfer_write before insert or update or delete on public.fantasy_transfer_events
for each row execute function public.guard_fantasy_transfer_write();

create or replace function public.guard_fantasy_powerup_write()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not public.fantasy_internal_write() then
    raise exception 'Power-ups can only be used by the fantasy rules engine';
  end if;
  return coalesce(new, old);
end;
$$;
drop trigger if exists guard_fantasy_powerup_write on public.fantasy_powerup_uses;
create trigger guard_fantasy_powerup_write before insert or update or delete on public.fantasy_powerup_uses
for each row execute function public.guard_fantasy_powerup_write();

create or replace function public.save_fantasy_squad(
  p_player_ids uuid[],
  p_slots integer[],
  p_captain_player_id uuid,
  p_lock boolean default false,
  p_period integer default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_manager public.fantasy_managers%rowtype;
  v_period integer;
  v_old_ids uuid[];
  v_removed uuid[];
  v_added uuid[];
  v_transfer_count integer;
  v_index integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(array_length(p_player_ids, 1), 0) <> 8 then raise exception 'A fantasy squad must contain eight players'; end if;
  if coalesce(array_length(p_slots, 1), 0) <> 8 then raise exception 'Each fantasy player must have a slot'; end if;
  select * into v_manager from public.fantasy_managers where id = auth.uid() for update;
  if not found then raise exception 'Fantasy manager profile not found'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  select coalesce(array_agg(player_id), '{}'::uuid[]) into v_old_ids from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';

  if v_manager.team_locked and p_lock then raise exception 'This team is permanently locked; use transfers or Wildcard'; end if;
  if v_manager.team_locked and not p_lock then
    if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
    select count(*) into v_transfer_count from public.fantasy_transfer_events where manager_id = auth.uid() and season = 'Season 05';
    if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;
    select coalesce(array_agg(x), '{}'::uuid[]) into v_removed from unnest(v_old_ids) x where not (x = any(p_player_ids));
    select coalesce(array_agg(x), '{}'::uuid[]) into v_added from unnest(p_player_ids) x where not (x = any(v_old_ids));
    if coalesce(array_length(v_removed, 1), 0) <> 1 or coalesce(array_length(v_added, 1), 0) <> 1 then raise exception 'A transfer must replace exactly one player'; end if;
  end if;

  perform set_config('fantasy.internal_write', 'on', true);
  delete from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  for v_index in 1..8 loop
    insert into public.fantasy_squads(manager_id, player_id, season, night, tier, slot, is_captain)
    select auth.uid(), p_player_ids[v_index], 'Season 05', v_period, category, p_slots[v_index], coalesce(p_player_ids[v_index] = p_captain_player_id, false)
    from public.players where id = p_player_ids[v_index];
  end loop;
  if p_lock then
    update public.fantasy_managers set team_locked = true, locked_at = now(), transfers_used = 0, transfer_period = v_period where id = auth.uid();
  else
    insert into public.fantasy_transfer_events(manager_id, season, period, from_player_id, to_player_id)
    values (auth.uid(), 'Season 05', v_period, v_removed[1], v_added[1]);
    update public.fantasy_managers set transfers_used = v_transfer_count + 1, transfer_period = v_period where id = auth.uid();
  end if;
  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', case when p_lock then 0 else v_transfer_count + 1 end);
end;
$$;

create or replace function public.set_fantasy_captain(p_player_id uuid, p_period integer default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_period integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  if exists (select 1 from public.fantasy_settings s where s.id = 'current' and coalesce(v_period, s.gameweek) = s.gameweek and now() >= coalesce(s.lock_at, s.deadline)) then raise exception 'Captain selection closes when the active deadline starts'; end if;
  if not exists (select 1 from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05' and player_id = p_player_id) then raise exception 'Captain must be one of your selected players'; end if;
  perform set_config('fantasy.internal_write', 'on', true);
  update public.fantasy_squads set is_captain = (player_id = p_player_id) where manager_id = auth.uid() and season = 'Season 05';
  update public.fantasy_manager_lineups set is_captain = (player_id = p_player_id) where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  return jsonb_build_object('ok', true, 'captain_player_id', p_player_id);
end;
$$;

create or replace function public.use_fantasy_powerup(p_powerup text, p_night integer, p_period integer default null, p_captain_player_id uuid default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare v_period integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  if exists (select 1 from public.fantasy_settings s where s.id = 'current' and s.gameweek = v_period and now() >= coalesce(s.lock_at, s.deadline)) then raise exception 'Power-ups close when the active deadline starts'; end if;
  if exists (select 1 from public.fantasy_powerup_uses where manager_id = auth.uid() and season = 'Season 05' and powerup = p_powerup) then raise exception 'This power-up has already been used'; end if;
  perform set_config('fantasy.internal_write', 'on', true);
  insert into public.fantasy_powerup_uses(manager_id, powerup, season, night, captain_player_id) values (auth.uid(), p_powerup, 'Season 05', p_night, p_captain_player_id);
  if p_powerup = 'wildcard' then
    delete from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
    delete from public.fantasy_manager_lineups where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
    update public.fantasy_managers set team_locked = false, wildcard_used = true, transfers_used = 0 where id = auth.uid();
  end if;
  return jsonb_build_object('ok', true, 'powerup', p_powerup);
end;
$$;

-- Remove broad client-side mutation paths. State transitions happen only through the RPCs above.
drop policy if exists "fantasy managers own record" on public.fantasy_managers;
drop policy if exists "users manage own manager profile" on public.fantasy_managers;
drop policy if exists "fantasy squads own record" on public.fantasy_squads;
drop policy if exists "users manage own squad" on public.fantasy_squads;
drop policy if exists "fantasy transfer events own record" on public.fantasy_transfer_events;
drop policy if exists "fantasy powerup uses own record" on public.fantasy_powerup_uses;
drop policy if exists "users create own powerup uses" on public.fantasy_powerup_uses;
create policy "fantasy managers own profile read" on public.fantasy_managers for select using (auth.uid() = id);
create policy "fantasy managers own profile insert" on public.fantasy_managers for insert with check (auth.uid() = id);
create policy "fantasy squads own read" on public.fantasy_squads for select using (auth.uid() = manager_id);
create policy "fantasy transfer events own read" on public.fantasy_transfer_events for select using (auth.uid() = manager_id);
create policy "fantasy powerup uses own read" on public.fantasy_powerup_uses for select using (auth.uid() = manager_id);
create policy "fantasy powerup uses own insert via engine" on public.fantasy_powerup_uses for insert with check (public.fantasy_internal_write() and auth.uid() = manager_id);
revoke update, delete on public.fantasy_managers from authenticated;
revoke insert, update, delete on public.fantasy_squads from authenticated;
revoke insert, update, delete on public.fantasy_transfer_events from authenticated;
revoke insert, update, delete on public.fantasy_powerup_uses from authenticated;
grant insert (id, team_name, display_name) on public.fantasy_managers to authenticated;

-- Existing broad score mutation policies are admin-only; managers can only read their ledgers.
drop policy if exists "authenticated manage manager gameweek scores" on public.fantasy_manager_gameweek_scores;
drop policy if exists "authenticated manage manager player scores" on public.fantasy_manager_player_scores;
create policy "admin manage manager gameweek scores" on public.fantasy_manager_gameweek_scores for all to authenticated using (is_admin()) with check (is_admin());
create policy "admin manage manager player scores" on public.fantasy_manager_player_scores for all to authenticated using (is_admin()) with check (is_admin());

-- Grants for the engine and admin-side security-definer execution.
grant execute on function public.save_fantasy_squad(uuid[], integer[], uuid, boolean, integer) to authenticated;
grant execute on function public.set_fantasy_captain(uuid, integer) to authenticated;
grant execute on function public.use_fantasy_powerup(text, integer, integer, uuid) to authenticated;

-- Unlocked managers may save partial squads while building; locked managers must use the two-transfer engine.
create or replace function public.save_fantasy_squad(
  p_player_ids uuid[], p_slots integer[], p_captain_player_id uuid,
  p_lock boolean default false, p_period integer default null
)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare
  v_manager public.fantasy_managers%rowtype; v_period integer; v_old_ids uuid[];
  v_removed uuid[]; v_added uuid[]; v_transfer_count integer; v_index integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(array_length(p_player_ids, 1), 0) > 8 or coalesce(array_length(p_slots, 1), 0) <> coalesce(array_length(p_player_ids, 1), 0) then raise exception 'A fantasy squad may contain at most eight players and every player needs a slot'; end if;
  if p_captain_player_id is not null and not (p_captain_player_id = any(p_player_ids)) then raise exception 'Captain must be in the selected squad'; end if;
  select * into v_manager from public.fantasy_managers where id = auth.uid() for update;
  if not found then raise exception 'Fantasy manager profile not found'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  select coalesce(array_agg(player_id), '{}'::uuid[]) into v_old_ids from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  if (p_lock or v_manager.team_locked) and coalesce(array_length(p_player_ids, 1), 0) <> 8 then raise exception 'A locked fantasy squad must contain eight players'; end if;
  if v_manager.team_locked and p_lock then raise exception 'This team is permanently locked; use transfers or Wildcard'; end if;
  if v_manager.team_locked and not p_lock then
    if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
    select count(*) into v_transfer_count from public.fantasy_transfer_events where manager_id = auth.uid() and season = 'Season 05';
    if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;
    select coalesce(array_agg(x), '{}'::uuid[]) into v_removed from unnest(v_old_ids) x where not (x = any(p_player_ids));
    select coalesce(array_agg(x), '{}'::uuid[]) into v_added from unnest(p_player_ids) x where not (x = any(v_old_ids));
    if coalesce(array_length(v_removed, 1), 0) <> 1 or coalesce(array_length(v_added, 1), 0) <> 1 then raise exception 'A transfer must replace exactly one player'; end if;
  end if;
  perform set_config('fantasy.internal_write', 'on', true);
  delete from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  for v_index in 1..coalesce(array_length(p_player_ids, 1), 0) loop
    insert into public.fantasy_squads(manager_id, player_id, season, night, tier, slot, is_captain)
    select auth.uid(), p_player_ids[v_index], 'Season 05', v_period, category, p_slots[v_index], coalesce(p_player_ids[v_index] = p_captain_player_id, false)
    from public.players where id = p_player_ids[v_index];
  end loop;
  if p_lock then
    update public.fantasy_managers set team_locked = true, locked_at = now(), transfers_used = 0, transfer_period = v_period where id = auth.uid();
  elsif v_manager.team_locked then
    insert into public.fantasy_transfer_events(manager_id, season, period, from_player_id, to_player_id) values (auth.uid(), 'Season 05', v_period, v_removed[1], v_added[1]);
    update public.fantasy_managers set transfers_used = v_transfer_count + 1, transfer_period = v_period where id = auth.uid();
  end if;
  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', case when p_lock or not v_manager.team_locked then 0 else v_transfer_count + 1 end);
end;
$$;


-- Managers may rename their own fantasy team without changing squad, lock, or transfer state.
create or replace function public.update_fantasy_manager_name(p_team_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_name text := btrim(coalesce(p_team_name, ''));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(v_team_name) < 2 then raise exception 'Team name must contain at least two characters'; end if;
  if char_length(v_team_name) > 40 then raise exception 'Team name must be 40 characters or fewer'; end if;
  update public.fantasy_managers
    set team_name = v_team_name, updated_at = now()
    where id = auth.uid();
  if not found then raise exception 'Fantasy manager profile not found'; end if;
  update public.profiles
    set team_name = v_team_name
    where id = auth.uid();
  update auth.users
    set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('team_name', v_team_name)
    where id = auth.uid();
  return jsonb_build_object('ok', true, 'team_name', v_team_name);
end;
$$;
grant execute on function public.update_fantasy_manager_name(text) to authenticated;
