grant select, insert, update, delete on public.fantasy_squads to authenticated;
grant select on public.fantasy_player_scores to anon, authenticated;

drop policy if exists "users manage own squad" on public.fantasy_squads;
create policy "users manage own squad" on public.fantasy_squads for all to authenticated using (auth.uid() = manager_id) with check (auth.uid() = manager_id);

drop policy if exists "public can read player scores" on public.fantasy_player_scores;
create policy "public can read player scores" on public.fantasy_player_scores for select to anon, authenticated using (true);
