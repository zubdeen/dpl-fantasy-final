create table if not exists public.fantasy_transfer_drafts (
  manager_id uuid not null references public.fantasy_managers(id) on delete cascade,
  season text not null default 'Season 05',
  period integer not null,
  from_player_id uuid not null references public.players(id),
  to_player_id uuid not null references public.players(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (manager_id, season, period)
);

alter table public.fantasy_transfer_drafts enable row level security;

drop policy if exists "fantasy transfer drafts own read" on public.fantasy_transfer_drafts;
create policy "fantasy transfer drafts own read"
on public.fantasy_transfer_drafts for select to authenticated
using (auth.uid() = manager_id);

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
  if not v_manager.team_locked then raise exception 'Lock your starting team before making transfers'; end if;

  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  if not public.fantasy_period_is_open(v_period) then raise exception 'Transfers open only after the active deadline ends'; end if;
  if exists (select 1 from public.fantasy_transfer_drafts where manager_id = auth.uid() and season = 'Season 05' and period = v_period) then
    raise exception 'Confirm your saved transfer before making another transfer';
  end if;

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
  update public.fantasy_managers set transfers_used = v_transfer_count + 1, transfer_period = v_period where id = auth.uid();

  return jsonb_build_object('ok', true, 'period', v_period, 'transfers_used', v_transfer_count + 1, 'pending', false);
end;
$$;

grant execute on function public.confirm_fantasy_transfer(integer) to authenticated;

create or replace function public.set_fantasy_captain(p_player_id uuid, p_period integer default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_period := coalesce(p_period, (select gameweek from public.fantasy_settings where id = 'current'), 1);
  if exists (
    select 1
    from public.fantasy_settings s
    where s.id = 'current'
      and s.gameweek = v_period
      and s.status = 'complete'
  ) then
    raise exception 'Captain selection is closed because this game night is complete';
  end if;
  if not exists (select 1 from public.fantasy_squads where manager_id = auth.uid() and season = 'Season 05' and player_id = p_player_id) then
    raise exception 'Captain must be one of your selected players';
  end if;
  perform set_config('fantasy.internal_write', 'on', true);
  update public.fantasy_squads set is_captain = (player_id = p_player_id) where manager_id = auth.uid() and season = 'Season 05';
  update public.fantasy_manager_lineups set is_captain = (player_id = p_player_id) where manager_id = auth.uid() and season = 'Season 05' and period = v_period;
  return jsonb_build_object('ok', true, 'captain_player_id', p_player_id);
end;
$$;

grant execute on function public.set_fantasy_captain(uuid, integer) to authenticated;
