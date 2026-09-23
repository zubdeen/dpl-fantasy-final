-- Use the current active game week as the transfer allowance period.
-- Managers may use the allowance awarded after the previous week completed
-- until the current week lock begins. Historical events remain untouched.
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
      and coalesce(p_period, s.gameweek) = s.gameweek
      and (
        s.status = 'complete'
        or (s.status = 'active' and (s.lock_at is null or now() < s.lock_at))
      )
  );
$$;

grant execute on function public.fantasy_period_is_open(integer) to authenticated;

do $$
declare
  v_period integer;
begin
  select gameweek into v_period
  from public.fantasy_settings
  where id = 'current';

  if v_period is not null then
    perform set_config('fantasy.internal_write', 'on', true);
    update public.fantasy_managers m
    set transfer_period = v_period,
        transfers_used = coalesce((
          select count(*)
          from public.fantasy_transfer_events e
          where e.manager_id = m.id
            and e.season = 'Season 05'
            and e.period = v_period
        ), 0)
    where coalesce(m.transfer_needs_lock, false) = false;
  end if;
end;
$$;

notify pgrst, 'reload schema';
