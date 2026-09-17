-- Transfers are available outside the active lock window:
-- before lock_at starts and after unlock_at ends. They remain blocked while
-- the game-night lock window is active.
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
      and s.lock_at is not null
      and s.unlock_at is not null
      and (now() < s.lock_at or now() >= s.unlock_at)
  );
$$;

grant execute on function public.fantasy_period_is_open(integer) to authenticated;
notify pgrst, 'reload schema';
