-- Remove the admin-only transfer correction feature. The original feature
-- migrations remain in source history, while these objects are removed from
-- the live schema.
drop policy if exists "fantasy transfer events admin read" on public.fantasy_transfer_events;
drop function if exists public.reset_manager_transfer(uuid, integer, uuid, boolean, text);
drop function if exists public.is_fantasy_admin();
drop table if exists public.fantasy_transfer_reset_audit;

-- Captains can be changed until the active lock window starts. Completion
-- remains a second defensive guard for completed game nights.
create or replace function public.set_fantasy_captain(p_player_id uuid, p_period integer default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  if exists (
    select 1
    from public.fantasy_settings s
    where s.id = 'current'
      and s.gameweek = v_period
      and s.lock_at is not null
      and now() >= s.lock_at
  ) then
    raise exception 'Captain selection is closed because the active lock window has started';
  end if;
  if exists (
    select 1
    from public.fantasy_settings s
    where s.id = 'current'
      and s.gameweek = v_period
      and s.status = 'complete'
  ) then
    raise exception 'Captain selection is closed because this game night is complete';
  end if;
  if not exists (select 1 from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05' and player_id = p_player_id) then
    raise exception 'Captain must be one of your selected players';
  end if;
  perform set_config('fantasy.internal_write', 'on', true);
  update public.fantasy_squads
  set is_captain = (player_id = p_player_id)
  where manager_id = auth.uid() and season = 'Season 05';
  update public.fantasy_manager_lineups
  set is_captain = (player_id = p_player_id)
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  return jsonb_build_object('ok', true, 'captain_player_id', p_player_id);
end;
$$;

grant execute on function public.set_fantasy_captain(uuid, integer) to authenticated;
notify pgrst, 'reload schema';
