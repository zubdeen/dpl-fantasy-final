create table if not exists public.fantasy_transfer_reset_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  manager_id uuid not null references public.fantasy_managers(id),
  event_id uuid not null,
  season text not null,
  period integer not null,
  restore_squad boolean not null default false,
  reason text not null,
  from_player_id uuid not null references public.players(id),
  to_player_id uuid not null references public.players(id),
  squad_before jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.fantasy_transfer_reset_audit enable row level security;

create or replace function public.is_fantasy_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and (
      exists (
        select 1
        from public.profiles
        where id = auth.uid()
          and lower(coalesce(role, '')) in ('admin', 'super_admin', 'administrator')
      )
      or lower(coalesce(auth.jwt() ->> 'email', '')) = 'dplbotswana@gmail.com'
    );
$$;

revoke all on function public.is_fantasy_admin() from public;
grant execute on function public.is_fantasy_admin() to authenticated;

drop policy if exists "fantasy transfer events admin read" on public.fantasy_transfer_events;
create policy "fantasy transfer events admin read"
on public.fantasy_transfer_events for select to authenticated
using (public.is_fantasy_admin());

drop policy if exists "fantasy transfer reset audit admin read" on public.fantasy_transfer_reset_audit;
create policy "fantasy transfer reset audit admin read"
on public.fantasy_transfer_reset_audit for select to authenticated
using (public.is_fantasy_admin());

create or replace function public.reset_manager_transfer(
  p_manager_id uuid,
  p_period integer,
  p_event_id uuid,
  p_restore_squad boolean default false,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.fantasy_transfer_events%rowtype;
  v_manager public.fantasy_managers%rowtype;
  v_squad_before jsonb;
  v_remaining integer;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_to_is_current boolean;
  v_has_later_event boolean;
begin
  if not public.is_fantasy_admin() then
    raise exception 'Administrator access required';
  end if;
  if p_manager_id is null or p_period is null or p_event_id is null then
    raise exception 'Manager, period, and transfer event are required';
  end if;
  if v_reason = '' then
    raise exception 'A reset reason is required';
  end if;
  if char_length(v_reason) > 500 then
    raise exception 'Reset reason must be 500 characters or fewer';
  end if;

  select * into v_event
  from public.fantasy_transfer_events
  where id = p_event_id
    and manager_id = p_manager_id
    and season = 'Season 05'
    and period = p_period
  for update;
  if not found then
    raise exception 'Transfer event was not found for this manager and period';
  end if;

  select * into v_manager
  from public.fantasy_managers
  where id = p_manager_id
  for update;
  if not found then
    raise exception 'Fantasy manager was not found';
  end if;

  select coalesce(jsonb_agg(to_jsonb(s) order by s.slot, s.tier), '[]'::jsonb)
  into v_squad_before
  from public.fantasy_squads s
  where s.manager_id = p_manager_id
    and s.season = 'Season 05';

  if p_restore_squad then
    select exists (
      select 1
      from public.fantasy_squads s
      where s.manager_id = p_manager_id
        and s.season = 'Season 05'
        and s.player_id = v_event.to_player_id
    ) into v_to_is_current;
    if not v_to_is_current then
      raise exception 'Cannot restore this transfer because the incoming player is no longer in the current squad';
    end if;

    select exists (
      select 1
      from public.fantasy_transfer_events later
      where later.manager_id = p_manager_id
        and later.season = 'Season 05'
        and later.period = p_period
        and later.created_at > v_event.created_at
    ) into v_has_later_event;
    if v_has_later_event then
      raise exception 'Restore is allowed only for the latest transfer in the period; reset allowance without restoring the squad instead';
    end if;
  end if;

  insert into public.fantasy_transfer_reset_audit(
    actor_id, manager_id, event_id, season, period, restore_squad,
    reason, from_player_id, to_player_id, squad_before
  ) values (
    auth.uid(), p_manager_id, v_event.id, v_event.season, v_event.period, p_restore_squad,
    v_reason, v_event.from_player_id, v_event.to_player_id, v_squad_before
  );

  perform set_config('fantasy.internal_write', 'on', true);
  delete from public.fantasy_transfer_events where id = v_event.id;

  if p_restore_squad then
    update public.fantasy_squads
    set player_id = v_event.from_player_id,
        tier = coalesce((select category from public.players where id = v_event.from_player_id), tier)
    where manager_id = p_manager_id
      and season = 'Season 05'
      and player_id = v_event.to_player_id;

    update public.fantasy_managers
    set team_locked = true,
        transfer_needs_lock = false,
        locked_at = coalesce(locked_at, now()),
        transfers_used = (
          select count(*) from public.fantasy_transfer_events
          where manager_id = p_manager_id and season = 'Season 05' and period = p_period
        ),
        transfer_period = p_period,
        updated_at = now()
    where id = p_manager_id;
  else
    select count(*) into v_remaining
    from public.fantasy_transfer_events
    where manager_id = p_manager_id
      and season = 'Season 05'
      and period = p_period;

    update public.fantasy_managers
    set transfers_used = v_remaining,
        transfer_period = p_period,
        updated_at = now()
    where id = p_manager_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'manager_id', p_manager_id,
    'period', p_period,
    'event_id', p_event_id,
    'restored_squad', p_restore_squad,
    'transfers_used', (
      select count(*) from public.fantasy_transfer_events
      where manager_id = p_manager_id and season = 'Season 05' and period = p_period
    )
  );
end;
$$;

revoke all on function public.reset_manager_transfer(uuid, integer, uuid, boolean, text) from public;
grant execute on function public.reset_manager_transfer(uuid, integer, uuid, boolean, text) to authenticated;

revoke all on table public.fantasy_transfer_reset_audit from anon, authenticated;
grant select on table public.fantasy_transfer_reset_audit to authenticated;

comment on function public.reset_manager_transfer(uuid, integer, uuid, boolean, text)
is 'Admin-only atomic correction for one confirmed fantasy transfer. Records an audit row and optionally restores the outgoing player.';

comment on table public.fantasy_transfer_reset_audit
is 'Immutable audit trail for administrator transfer corrections.';

-- The current admin console authenticates this configured administrator account.
-- Role-based administrators can also use the RPC once their profiles.role is set to admin.
-- Current configured admin: dplbotswana@gmail.com.

notify pgrst, 'reload schema';
