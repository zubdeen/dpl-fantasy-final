-- Reset only the current-week player display ledger when a game week is
-- completed or a new active game week is selected. Historical manager points
-- remain in fantasy_manager_player_scores and fantasy_manager_gameweek_scores.
create or replace function public.reset_current_fantasy_player_scores_on_week_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.season = 'Season 05'
     and (
       (new.gameweek is distinct from old.gameweek and new.status = 'active')
       or (new.status = 'complete' and old.status is distinct from 'complete')
     ) then
    delete from public.fantasy_player_scores
    where season = 'Season 05';

    delete from public.fantasy_fixture_player_points
    where season = 'Season 05';
  end if;

  return new;
end;
$$;

drop trigger if exists reset_current_fantasy_player_scores_on_week_transition on public.fantasy_settings;
create trigger reset_current_fantasy_player_scores_on_week_transition
after update of status, gameweek on public.fantasy_settings
for each row
execute function public.reset_current_fantasy_player_scores_on_week_transition();

notify pgrst, 'reload schema';
