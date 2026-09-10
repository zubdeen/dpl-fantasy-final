-- Auth callbacks use the authenticated PostgREST role to create and update
-- the user's profile. Manager rows are created once and never updated here;
-- state changes remain behind the fantasy rules engine.
grant select, insert, update on public.profiles to authenticated;
grant insert on public.fantasy_managers to authenticated;
