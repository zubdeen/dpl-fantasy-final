-- Users can always read their saved squad, but lineup mutations are blocked after the current deadline.
drop policy if exists "users manage own squad" on public.fantasy_squads;
drop policy if exists "users read own squad" on public.fantasy_squads;
drop policy if exists "users insert own squad before deadline" on public.fantasy_squads;
drop policy if exists "users update own squad before deadline" on public.fantasy_squads;
drop policy if exists "users delete own squad before deadline" on public.fantasy_squads;
create policy "users read own squad" on public.fantasy_squads for select to authenticated using (auth.uid() = manager_id);
create policy "users insert own squad before deadline" on public.fantasy_squads for insert to authenticated with check (auth.uid() = manager_id and exists (select 1 from public.fantasy_settings s where s.id = 'current' and now() < s.deadline));
create policy "users update own squad before deadline" on public.fantasy_squads for update to authenticated using (auth.uid() = manager_id and exists (select 1 from public.fantasy_settings s where s.id = 'current' and now() < s.deadline)) with check (auth.uid() = manager_id and exists (select 1 from public.fantasy_settings s where s.id = 'current' and now() < s.deadline));
create policy "users delete own squad before deadline" on public.fantasy_squads for delete to authenticated using (auth.uid() = manager_id and exists (select 1 from public.fantasy_settings s where s.id = 'current' and now() < s.deadline));

drop policy if exists "users create own powerup uses" on public.fantasy_powerup_uses;
create policy "users create own powerup uses before deadline" on public.fantasy_powerup_uses for insert to authenticated with check (auth.uid() = manager_id and exists (select 1 from public.fantasy_settings s where s.id = 'current' and now() < s.deadline));
