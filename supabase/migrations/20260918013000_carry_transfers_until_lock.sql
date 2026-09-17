-- Carry a manager's existing free-transfer allowance into a newly active
-- game week. A new active week does not reset the manager's transfer period;
-- the allowance is reset only when the previous week is marked complete.
create or replace function public.fantasy_period_is_open(p_period integer default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.fantasy_settings s
    where s.id = 'current'
      and (
        (coalesce(p_period, s.gameweek) = s.gameweek and s.status = 'complete')
        or
        (coalesce(p_period, s.gameweek) < s.gameweek
          and s.status = 'active'
          and (s.lock_at is null or now() < s.lock_at))
      )
  );
$$;

grant execute on function public.fantasy_period_is_open(integer) to authenticated;

create or replace function public.sync_fantasy_transfer_period_on_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'complete' and old.status is distinct from 'complete' then
    update public.fantasy_managers
    set transfers_used = 0,
        transfer_period = new.gameweek
    where transfer_period <= new.gameweek;

    delete from public.fantasy_transfer_drafts
    where period < new.gameweek;
  end if;
  return new;
end;
$$;

drop trigger if exists fantasy_settings_transfer_period_complete on public.fantasy_settings;
create trigger fantasy_settings_transfer_period_complete
after update of status, gameweek on public.fantasy_settings
for each row execute function public.sync_fantasy_transfer_period_on_complete();

notify pgrst, 'reload schema';
