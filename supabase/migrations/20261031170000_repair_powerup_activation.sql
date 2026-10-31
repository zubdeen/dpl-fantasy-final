-- Repair power-up activation after the current-gameweek migration.
-- Seasonal cards are one-use; Diamond is reusable once per game night.
create or replace function public.use_fantasy_powerup(
  p_powerup text,
  p_night integer,
  p_period integer default null,
  p_captain_player_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_powerup not in ('diamond', 'no_negative', 'wildcard', 'diamond_boost') then
    raise exception 'Unknown power-up';
  end if;

  select coalesce(gameweek, night, p_period, p_night)
    into v_period
  from public.fantasy_settings
  where id = 'current';

  if v_period is null then
    raise exception 'No active game week is configured';
  end if;

  if exists (
    select 1
    from public.fantasy_settings
    where id = 'current'
      and now() >= coalesce(lock_at, deadline)
  ) then
    raise exception 'Power-ups close when the active deadline starts';
  end if;

  if exists (
    select 1
    from public.fantasy_powerup_uses
    where manager_id = auth.uid()
      and season = 'Season 05'
      and powerup = p_powerup
      and (p_powerup <> 'diamond' or night = v_period)
  ) then
    raise exception 'This power-up has already been used';
  end if;

  perform set_config('fantasy.internal_write', 'on', true);

  insert into public.fantasy_powerup_uses(
    manager_id, powerup, season, night, captain_player_id
  )
  values (
    auth.uid(), p_powerup, 'Season 05', v_period, p_captain_player_id
  );

  if p_powerup = 'wildcard' then
    delete from public.fantasy_squads
    where manager_id = auth.uid() and season = 'Season 05';
    delete from public.fantasy_manager_lineups
    where manager_id = auth.uid()
      and season = 'Season 05'
      and period = v_period;
    update public.fantasy_managers
    set team_locked = false, wildcard_used = true, transfers_used = 0
    where id = auth.uid();
  end if;

  return jsonb_build_object('ok', true, 'powerup', p_powerup, 'period', v_period);
end;
$$;

grant execute on function public.use_fantasy_powerup(text, integer, integer, uuid) to authenticated;
notify pgrst, 'reload schema';
