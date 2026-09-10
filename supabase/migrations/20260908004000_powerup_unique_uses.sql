create unique index if not exists fantasy_powerup_season_once_idx on public.fantasy_powerup_uses(manager_id, powerup, season) where powerup in ('no_negative','wildcard','diamond_boost');
create unique index if not exists fantasy_powerup_diamond_night_idx on public.fantasy_powerup_uses(manager_id, powerup, season, night) where powerup = 'diamond';
