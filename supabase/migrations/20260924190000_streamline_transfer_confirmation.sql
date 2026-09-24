-- Streamline transfers: after saving a transfer, managers may only cancel or
-- confirm it. Confirmation keeps the team locked and permits the second transfer
-- immediately; Diamond selection remains an independent action before lock.

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
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers are closed during the active lock window'; end if;

  select * into v_draft
  from public.fantasy_transfer_drafts
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period
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

  return jsonb_build_object(
    'ok', true,
    'period', v_period,
    'transfers_used', v_transfer_count + 1,
    'pending', false,
    'needs_lock', false
  );
end;
$$;

grant execute on function public.confirm_fantasy_transfer(integer) to authenticated;

create or replace function public.cancel_fantasy_transfer(p_period integer default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period integer;
  v_draft public.fantasy_transfer_drafts%rowtype;
  v_was_captain boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);

  select * into v_draft
  from public.fantasy_transfer_drafts
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period
  for update;
  if not found then raise exception 'There is no saved transfer to cancel'; end if;

  select coalesce(is_captain, false) into v_was_captain
  from public.fantasy_squads
  where manager_id = auth.uid() and season = 'Season 05' and player_id = v_draft.to_player_id;

  perform set_config('fantasy.internal_write', 'on', true);
  update public.fantasy_squads s
  set player_id = v_draft.from_player_id,
      tier = p.category,
      is_captain = v_was_captain
  from public.players p
  where s.manager_id = auth.uid()
    and s.season = 'Season 05'
    and s.player_id = v_draft.to_player_id
    and p.id = v_draft.from_player_id;

  delete from public.fantasy_transfer_drafts
  where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  update public.fantasy_managers
  set team_locked = true,
      transfer_needs_lock = false,
      transfer_period = v_period
  where id = auth.uid();

  return jsonb_build_object('ok', true, 'period', v_period, 'pending', false);
end;
$$;

grant execute on function public.cancel_fantasy_transfer(integer) to authenticated;

notify pgrst, 'reload schema';
