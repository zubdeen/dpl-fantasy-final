-- Invalidate unfinished transfer drafts when the fantasy game week advances.
-- A saved transfer is a draft until it is confirmed: it may temporarily mutate
-- fantasy_squads, so stale drafts must be reversed before they are invalidated.

alter table public.fantasy_transfer_drafts
  add column if not exists invalidated_at timestamptz,
  add column if not exists invalidation_reason text;

create index if not exists fantasy_transfer_drafts_active_lookup
  on public.fantasy_transfer_drafts (season, period, invalidated_at);

create or replace function public.invalidate_stale_fantasy_transfer_drafts(p_current_period integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_draft public.fantasy_transfer_drafts%rowtype;
  v_invalidated integer := 0;
  v_was_captain boolean;
begin
  if p_current_period is null then
    return 0;
  end if;

  perform set_config('fantasy.internal_write', 'on', true);

  -- Reverse in descending period order because a later unfinished draft may
  -- have been built on top of an earlier unfinished draft.
  for v_draft in
    select d.*
    from public.fantasy_transfer_drafts d
    where d.season = 'Season 05'
      and d.period < p_current_period
      and d.invalidated_at is null
    order by d.manager_id, d.period desc, d.created_at desc
    for update
  loop
    select coalesce(s.is_captain, false)
      into v_was_captain
    from public.fantasy_squads s
    where s.manager_id = v_draft.manager_id
      and s.season = v_draft.season
      and s.player_id = v_draft.to_player_id
    limit 1;

    -- The saved draft temporarily replaced from_player with to_player in the
    -- squad table. Restore the exact previous player before invalidating it.
    update public.fantasy_squads s
    set player_id = v_draft.from_player_id,
        tier = p.category,
        is_captain = coalesce(v_was_captain, false)
    from public.players p
    where s.manager_id = v_draft.manager_id
      and s.season = v_draft.season
      and s.player_id = v_draft.to_player_id
      and p.id = v_draft.from_player_id;

    update public.fantasy_transfer_drafts
    set invalidated_at = now(),
        invalidation_reason = 'Game week advanced before transfer confirmation',
        updated_at = now()
    where manager_id = v_draft.manager_id
      and season = v_draft.season
      and period = v_draft.period
      and invalidated_at is null;

    v_invalidated := v_invalidated + 1;
  end loop;

  return v_invalidated;
end;
$$;

revoke all on function public.invalidate_stale_fantasy_transfer_drafts(integer) from public, authenticated;

-- Run cleanup from every transfer entry point as a safety net, including cases
-- where the admin changed the active week without a settings update trigger.
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
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
  if exists (
    select 1 from public.fantasy_transfer_drafts
    where manager_id = auth.uid() and season = 'Season 05' and period = v_period and invalidated_at is null
  ) then
    raise exception 'Confirm your saved transfer before making another transfer';
  end if;
  if not v_manager.team_locked then raise exception 'Lock your starting team before making transfers'; end if;

  select count(*) into v_transfer_count
  from public.fantasy_transfer_events
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;

  select coalesce(array_agg(player_id order by slot), '{}'::uuid[])
  into v_old_ids
  from public.fantasy_squads
  where manager_id = auth.uid() and season = 'Season 05';
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

-- Keep the confirm path safe if a stale draft survived until the next request.
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
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers are closed during the active lock window'; end if;

  select * into v_draft
  from public.fantasy_transfer_drafts
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period and invalidated_at is null
  for update;
  if not found then raise exception 'Save a transfer before confirming it'; end if;

  select count(*) into v_transfer_count
  from public.fantasy_transfer_events
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;

  if not exists (
    select 1 from public.fantasy_squads
    where manager_id = auth.uid() and season = 'Season 05' and player_id = v_draft.to_player_id
  ) then
    raise exception 'The saved transfer no longer matches your current squad';
  end if;

  v_origin_ids := public.fantasy_transfer_origin_ids(auth.uid(), v_period, v_draft.from_player_id, v_draft.to_player_id);
  if not (v_draft.from_player_id = any(v_origin_ids)) then
    raise exception 'A transfer must remove a player from your original locked team';
  end if;

  perform set_config('fantasy.internal_write', 'on', true);
  insert into public.fantasy_transfer_events(manager_id, season, period, from_player_id, to_player_id)
  values (auth.uid(), 'Season 05', v_period, v_draft.from_player_id, v_draft.to_player_id);
  delete from public.fantasy_transfer_drafts
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  update public.fantasy_managers
  set transfers_used = v_transfer_count + 1,
      transfer_period = v_period,
      team_locked = true,
      transfer_needs_lock = false
  where id = auth.uid();

  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', v_transfer_count + 1, 'pending', false, 'needs_lock', false);
end;
$$;

grant execute on function public.confirm_fantasy_transfer(integer) to authenticated;

-- Replace deletion on week completion with reversible invalidation + squad restore.
create or replace function public.sync_fantasy_transfer_period_on_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.invalidate_stale_fantasy_transfer_drafts(new.gameweek);
  elsif new.gameweek is distinct from old.gameweek or new.status is distinct from old.status then
    perform public.invalidate_stale_fantasy_transfer_drafts(new.gameweek);
  end if;

  if new.status = 'complete' and (tg_op = 'INSERT' or old.status is distinct from 'complete') then
    update public.fantasy_managers
    set transfers_used = 0,
        transfer_period = new.gameweek
    where transfer_period <= new.gameweek;
  end if;
  return new;
end;
$$;

drop trigger if exists fantasy_settings_transfer_period_complete on public.fantasy_settings;
create trigger fantasy_settings_transfer_period_complete
after insert or update of status, gameweek on public.fantasy_settings
for each row execute function public.sync_fantasy_transfer_period_on_complete();

-- Invalidate any already-stale drafts now, preserving the manager's current
-- saved/locked squad while making a clean current-period transfer available.
select public.invalidate_stale_fantasy_transfer_drafts(
  (select gameweek from public.fantasy_settings where id = 'current')
);

notify pgrst, 'reload schema';
