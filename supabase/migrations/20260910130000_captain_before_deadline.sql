create or replace function public.set_fantasy_captain(p_player_id uuid, p_period integer default null)
returns jsonb
language plpgsql
security definer set search_path = public
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
      and now() >= coalesce(s.lock_at, s.deadline)
  ) then
    raise exception 'Captain selection closes when the active deadline starts';
  end if;
  if not exists (select 1 from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05' and player_id = p_player_id) then
    raise exception 'Captain must be one of your selected players';
  end if;
  perform set_config('fantasy.internal_write', 'on', true);
  update public.fantasy_squads set is_captain = (player_id = p_player_id) where manager_id = auth.uid() and season = 'Season 05';
  update public.fantasy_manager_lineups set is_captain = (player_id = p_player_id) where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  return jsonb_build_object('ok', true, 'captain_player_id', p_player_id);
end;
$$;

grant execute on function public.set_fantasy_captain(uuid, integer) to authenticated;
