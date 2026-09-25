-- Normalize managers created under the previous post-transfer flow.
-- A confirmed transfer is already a locked team in the current flow; Diamond
-- selection is independent and must not block the next transfer.

create or replace function public.normalize_legacy_fantasy_transfer_lock_state(p_period integer default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_normalized integer := 0;
begin
  perform set_config('fantasy.internal_write', 'on', true);

  update public.fantasy_managers m
  set team_locked = true,
      transfer_needs_lock = false
  where m.team_locked = false
    and m.transfer_needs_lock = true
    and (select count(*) from public.fantasy_squads s where s.manager_id = m.id and s.season = 'Season 05') = 8
    and exists (
      select 1 from public.fantasy_transfer_events e
      where e.manager_id = m.id and e.season = 'Season 05'
    )
    and not exists (
      select 1 from public.fantasy_transfer_drafts d
      where d.manager_id = m.id and d.season = 'Season 05' and d.invalidated_at is null
    );

  get diagnostics v_normalized = row_count;
  return v_normalized;
end;
$$;

revoke all on function public.normalize_legacy_fantasy_transfer_lock_state(integer) from public, authenticated;

-- Run normalization whenever the active week changes, and from transfer RPCs
-- as a safety net for managers whose old state predates this migration.
create or replace function public.save_fantasy_transfer(
  p_player_ids uuid[],
  p_slots integer[],
  p_captain_player_id uuid,
  p_period integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_manager public.fantasy_managers%rowtype;
  v_period integer;
  v_old_ids uuid[];
  v_removed uuid[];
  v_added uuid[];
  v_transfer_count integer;
  v_index integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(array_length(p_player_ids, 1), 0) <> 8 then raise exception 'A transfer must leave you with eight players'; end if;
  if coalesce(array_length(p_slots, 1), 0) <> coalesce(array_length(p_player_ids, 1), 0) then raise exception 'Every player needs a slot'; end if;
  if p_captain_player_id is not null and not (p_captain_player_id = any(p_player_ids)) then raise exception 'Captain must be one of your selected players'; end if;

  select * into v_manager from public.fantasy_managers where id = auth.uid() for update;
  if not found then raise exception 'Fantasy manager profile not found'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  perform public.invalidate_stale_fantasy_transfer_drafts(v_period);
  perform public.normalize_legacy_fantasy_transfer_lock_state(v_period);
  select * into v_manager from public.fantasy_managers where id = auth.uid() for update;
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
  if exists (select 1 from public.fantasy_transfer_drafts where manager_id = auth.uid() and season = 'Season 05' and period = v_period and invalidated_at is null) then raise exception 'Confirm your saved transfer before making another transfer'; end if;
  if not v_manager.team_locked then raise exception 'Lock your starting team before making transfers'; end if;

  select count(*) into v_transfer_count from public.fantasy_transfer_events where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;
  select coalesce(array_agg(player_id order by slot), '{}'::uuid[]) into v_old_ids from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  select coalesce(array_agg(x), '{}'::uuid[]) into v_removed from unnest(v_old_ids) x where not (x = any(p_player_ids));
  select coalesce(array_agg(x), '{}'::uuid[]) into v_added from unnest(p_player_ids) x where not (x = any(v_old_ids));
  if coalesce(array_length(v_removed, 1), 0) <> 1 or coalesce(array_length(v_added, 1), 0) <> 1 then raise exception 'A transfer must replace exactly one player'; end if;

  perform set_config('fantasy.internal_write', 'on', true);
  delete from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  for v_index in 1..array_length(p_player_ids, 1) loop
    insert into public.fantasy_squads(manager_id, player_id, season, night, tier, slot, is_captain)
    select auth.uid(), p_player_ids[v_index], 'Season 05', v_period, category, p_slots[v_index], coalesce(p_player_ids[v_index] = p_captain_player_id, false)
    from public.players where id = p_player_ids[v_index];
  end loop;
  insert into public.fantasy_transfer_drafts(manager_id, season, period, from_player_id, to_player_id)
  values (auth.uid(), 'Season 05', v_period, v_removed[1], v_added[1]);
  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', v_transfer_count, 'pending', true);
end;
$$;

grant execute on function public.save_fantasy_transfer(uuid[], integer[], uuid, integer) to authenticated;

-- Normalize first, then confirm. The confirmation path always ends in the
-- current locked state and never requires a separate Diamond/team lock step.
create or replace function public.confirm_fantasy_transfer(p_period integer default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period integer;
  v_transfer_count integer;
  v_draft public.fantasy_transfer_drafts%rowtype;
  v_origin_ids uuid[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  perform public.invalidate_stale_fantasy_transfer_drafts(v_period);
  perform public.normalize_legacy_fantasy_transfer_lock_state(v_period);
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers are closed during the active lock window'; end if;
  select * into v_draft from public.fantasy_transfer_drafts where manager_id = auth.uid() and season = 'Season 05' and period = v_period and invalidated_at is null for update;
  if not found then raise exception 'Save a transfer before confirming it'; end if;
  select count(*) into v_transfer_count from public.fantasy_transfer_events where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;
  if not exists (select 1 from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05' and player_id = v_draft.to_player_id) then raise exception 'The saved transfer no longer matches your current squad'; end if;
  v_origin_ids := public.fantasy_transfer_origin_ids(auth.uid(), v_period, v_draft.from_player_id, v_draft.to_player_id);
  if not (v_draft.from_player_id = any(v_origin_ids)) then raise exception 'A transfer must remove a player from your original locked team'; end if;
  perform set_config('fantasy.internal_write', 'on', true);
  insert into public.fantasy_transfer_events(manager_id, season, period, from_player_id, to_player_id) values (auth.uid(), 'Season 05', v_period, v_draft.from_player_id, v_draft.to_player_id);
  delete from public.fantasy_transfer_drafts where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  update public.fantasy_managers set transfers_used = v_transfer_count + 1, transfer_period = v_period, team_locked = true, transfer_needs_lock = false where id = auth.uid();
  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', v_transfer_count + 1, 'pending', false, 'needs_lock', false);
end;
$$;

grant execute on function public.confirm_fantasy_transfer(integer) to authenticated;

create or replace function public.sync_fantasy_transfer_period_on_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.invalidate_stale_fantasy_transfer_drafts(new.gameweek);
    perform public.normalize_legacy_fantasy_transfer_lock_state(new.gameweek);
  elsif new.gameweek is distinct from old.gameweek or new.status is distinct from old.status then
    perform public.invalidate_stale_fantasy_transfer_drafts(new.gameweek);
    perform public.normalize_legacy_fantasy_transfer_lock_state(new.gameweek);
  end if;
  if new.status = 'complete' and (tg_op = 'INSERT' or old.status is distinct from 'complete') then
    update public.fantasy_managers set transfers_used = 0, transfer_period = new.gameweek where transfer_period <= new.gameweek;
  end if;
  return new;
end;
$$;

drop trigger if exists fantasy_settings_transfer_period_complete on public.fantasy_settings;
create trigger fantasy_settings_transfer_period_complete
after insert or update of status, gameweek on public.fantasy_settings
for each row execute function public.sync_fantasy_transfer_period_on_complete();

-- Normalize existing legacy accounts now. This does not alter transfer events,
-- transfer counts, squads, or allowances.
select public.normalize_legacy_fantasy_transfer_lock_state(
  (select gameweek from public.fantasy_settings where id = 'current')
);

notify pgrst, 'reload schema';
