alter table public.fantasy_managers
  add column if not exists transfer_needs_lock boolean not null default false;

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
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
  select * into v_draft
  from public.fantasy_transfer_drafts
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period
  for update;
  if not found then raise exception 'Save a transfer before confirming it'; end if;

  select count(*) into v_transfer_count
  from public.fantasy_transfer_events
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;

  perform set_config('fantasy.internal_write', 'on', true);
  insert into public.fantasy_transfer_events(manager_id, season, period, from_player_id, to_player_id)
  values (auth.uid(), 'Season 05', v_period, v_draft.from_player_id, v_draft.to_player_id);
  delete from public.fantasy_transfer_drafts where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  update public.fantasy_managers
  set transfers_used = v_transfer_count + 1,
      transfer_period = v_period,
      team_locked = false,
      transfer_needs_lock = true
  where id = auth.uid();

  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', v_transfer_count + 1, 'pending', false, 'needs_lock', true);
end;
$$;

grant execute on function public.confirm_fantasy_transfer(integer) to authenticated;

create or replace function public.save_fantasy_squad(
  p_player_ids uuid[], p_slots integer[], p_captain_player_id uuid,
  p_lock boolean default false, p_period integer default null
)
returns jsonb language plpgsql security definer set search_path = public
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
  if coalesce(array_length(p_player_ids, 1), 0) > 8 or coalesce(array_length(p_slots, 1), 0) <> coalesce(array_length(p_player_ids, 1), 0) then raise exception 'A fantasy squad may contain at most eight players and every player needs a slot'; end if;
  if p_captain_player_id is not null and not (p_captain_player_id = any(p_player_ids)) then raise exception 'Captain must be in the selected squad'; end if;
  select * into v_manager from public.fantasy_managers where id = auth.uid() for update;
  if not found then raise exception 'Fantasy manager profile not found'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  select coalesce(array_agg(player_id), '{}'::uuid[]) into v_old_ids from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  if (p_lock or v_manager.team_locked or v_manager.transfer_needs_lock) and coalesce(array_length(p_player_ids, 1), 0) <> 8 then raise exception 'A locked fantasy squad must contain eight players'; end if;
  if v_manager.team_locked and p_lock then raise exception 'This team is permanently locked; use transfers or Wildcard'; end if;

  if v_manager.transfer_needs_lock and not p_lock then
    select coalesce(array_agg(x), '{}'::uuid[]) into v_removed from unnest(v_old_ids) x where not (x = any(p_player_ids));
    select coalesce(array_agg(x), '{}'::uuid[]) into v_added from unnest(p_player_ids) x where not (x = any(v_old_ids));
    if coalesce(array_length(v_removed, 1), 0) <> 0 or coalesce(array_length(v_added, 1), 0) <> 0 then raise exception 'Choose your Diamond and lock the team before making another player change'; end if;
  elsif v_manager.team_locked and not p_lock then
    if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
    select count(*) into v_transfer_count from public.fantasy_transfer_events where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
    if v_transfer_count >= 2 then raise exception 'Both free transfers have already been used'; end if;
    select coalesce(array_agg(x), '{}'::uuid[]) into v_removed from unnest(v_old_ids) x where not (x = any(p_player_ids));
    select coalesce(array_agg(x), '{}'::uuid[]) into v_added from unnest(p_player_ids) x where not (x = any(v_old_ids));
    if coalesce(array_length(v_removed, 1), 0) <> 1 or coalesce(array_length(v_added, 1), 0) <> 1 then raise exception 'A transfer must replace exactly one player'; end if;
  end if;

  perform set_config('fantasy.internal_write', 'on', true);
  delete from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05';
  for v_index in 1..coalesce(array_length(p_player_ids, 1), 0) loop
    insert into public.fantasy_squads(manager_id, player_id, season, night, tier, slot, is_captain)
    select auth.uid(), p_player_ids[v_index], 'Season 05', v_period, category, p_slots[v_index], coalesce(p_player_ids[v_index] = p_captain_player_id, false)
    from public.players where id = p_player_ids[v_index];
  end loop;

  if p_lock then
    update public.fantasy_managers
    set team_locked = true, transfer_needs_lock = false, locked_at = now(), transfers_used = case when v_manager.transfer_needs_lock then v_manager.transfers_used else 0 end, transfer_period = v_period
    where id = auth.uid();
  elsif v_manager.team_locked then
    insert into public.fantasy_transfer_events(manager_id, season, period, from_player_id, to_player_id) values (auth.uid(), 'Season 05', v_period, v_removed[1], v_added[1]);
    update public.fantasy_managers set transfers_used = v_transfer_count + 1, transfer_period = v_period where id = auth.uid();
  end if;
  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', case when p_lock and v_manager.transfer_needs_lock then v_manager.transfers_used when p_lock then 0 when not v_manager.team_locked then 0 else v_transfer_count + 1 end, 'needs_lock', case when p_lock then false else v_manager.transfer_needs_lock end);
end;
$$;

grant execute on function public.save_fantasy_squad(uuid[], integer[], uuid, boolean, integer) to authenticated;
