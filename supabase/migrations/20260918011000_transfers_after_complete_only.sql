-- Free transfers are awarded only after the current game week is marked complete.
-- Timestamp windows alone must not grant transfers for a newly active week.
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
  );
$$;

grant execute on function public.fantasy_period_is_open(integer) to authenticated;
notify pgrst, 'reload schema';
