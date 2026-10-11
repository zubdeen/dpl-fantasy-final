-- Keep overall totals sourced from the authoritative manager game-week ledger.
create or replace function public.apply_fantasy_no_negative_to_manager(
  p_manager_id uuid,
  p_gameweek integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_overall_points integer;
begin
  if p_manager_id is null or p_gameweek is null then
    return;
  end if;

  update public.fantasy_manager_player_scores
  set points = greatest(points, 0), updated_at = now()
  where manager_id = p_manager_id
    and season = 'Season 05'
    and gameweek = p_gameweek
    and points < 0;

  update public.fantasy_manager_gameweek_scores
  set points = coalesce((
        select sum(points)::integer
        from public.fantasy_manager_player_scores
        where manager_id = p_manager_id
          and season = 'Season 05'
          and gameweek = p_gameweek
      ), 0),
      updated_at = now()
  where manager_id = p_manager_id
    and season = 'Season 05'
    and gameweek = p_gameweek;

  select coalesce(sum(points), 0)::integer
    into v_overall_points
  from public.fantasy_manager_gameweek_scores
  where manager_id = p_manager_id
    and season = 'Season 05';

  update public.fantasy_manager_gameweek_scores
  set overall_points = v_overall_points,
      updated_at = now()
  where manager_id = p_manager_id
    and season = 'Season 05';
end;
$$;

-- Recalculate every activation using the corrected authoritative-total logic.
do $$
declare
  v_use record;
begin
  for v_use in
    select manager_id, night
    from public.fantasy_powerup_uses
    where season = 'Season 05'
      and powerup = 'no_negative'
  loop
    perform public.apply_fantasy_no_negative_to_manager(v_use.manager_id, v_use.night);
  end loop;
end;
$$;

grant execute on function public.apply_fantasy_no_negative_to_manager(uuid, integer) to authenticated;
notify pgrst, 'reload schema';
