-- Keep completed-week transfers closed during any active lock window.
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
      and s.status = 'complete'
      and (s.lock_at is null or s.unlock_at is null or now() < s.lock_at or now() >= s.unlock_at)
  );
$$;

grant execute on function public.fantasy_period_is_open(integer) to authenticated;
notify pgrst, 'reload schema';
