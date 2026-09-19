-- 083_privileged_role_aal2_boundary.sql
-- Enforces the application's privileged-role MFA contract at the database boundary.
-- Agents remain AAL1-capable for assigned-book work; admin/manager/compliance/revenue
-- must reach AAL2 before tenant data becomes available.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.current_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, auth
as $$
  select m.organization_id
  from public.memberships m
  where m.user_id=(select auth.uid())
    and m.is_active=true
    and (
      m.role='agent'
      or (
        m.role in ('agency_admin','manager','compliance','revenue')
        and coalesce((auth.jwt()->>'aal')='aal2',false)
      )
    )
$$;

revoke all on function app_private.current_org_ids()
from public, anon;
grant execute on function app_private.current_org_ids()
to authenticated;

create or replace function app_private.has_org_role(
  target_org uuid,
  allowed public.member_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.memberships m
    where m.user_id=(select auth.uid())
      and m.organization_id=target_org
      and m.is_active=true
      and m.role=any(allowed)
      and (
        m.role='agent'
        or coalesce((auth.jwt()->>'aal')='aal2',false)
      )
  )
$$;

revoke all on function app_private.has_org_role(uuid,public.member_role[])
from public, anon;
grant execute on function app_private.has_org_role(uuid,public.member_role[])
to authenticated;

-- A user can always read their own active/inactive membership rows so the app
-- can discover the required role and route them to MFA. Seeing other members
-- remains an AAL2 management action.
drop policy if exists memberships_select on public.memberships;
create policy memberships_select on public.memberships
for select to authenticated
using (
  user_id=(select auth.uid())
  or (
    organization_id in (select app_private.current_org_ids())
    and app_private.has_org_role(
      organization_id,
      array['agency_admin','manager']::public.member_role[]
    )
  )
);

create or replace function app_private.can_manage_assignment(
  target_org uuid,
  target_office uuid,
  target_assigned_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.memberships m
    where m.user_id=(select auth.uid())
      and m.organization_id=target_org
      and m.is_active=true
      and (
        (
          m.role in ('agency_admin','manager')
          and coalesce((auth.jwt()->>'aal')='aal2',false)
        )
        or (
          m.role='agent'
          and target_assigned_user=(select auth.uid())
          and (
            target_office is null
            or m.office_id=target_office
          )
        )
      )
  )
$$;

revoke all on function app_private.can_manage_assignment(uuid,uuid,uuid)
from public, anon;
grant execute on function app_private.can_manage_assignment(uuid,uuid,uuid)
to authenticated;

create or replace function app_private.can_view_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    exists(
      select 1
      from public.client_portal_accounts p
      where p.client_id=target_client
        and p.user_id=(select auth.uid())
        and p.status='active'
    )
    or exists(
      select 1
      from public.clients c
      join public.memberships m
        on m.organization_id=c.organization_id
      where c.id=target_client
        and m.user_id=(select auth.uid())
        and m.is_active=true
        and (
          (
            m.role in ('agency_admin','manager','compliance','revenue')
            and coalesce((auth.jwt()->>'aal')='aal2',false)
          )
          or (
            m.role='agent'
            and c.assigned_user_id=(select auth.uid())
            and (
              c.office_id is null
              or m.office_id=c.office_id
            )
          )
        )
    )
$$;

revoke all on function app_private.can_view_client(uuid)
from public, anon;
grant execute on function app_private.can_view_client(uuid)
to authenticated;

create or replace function app_private.can_view_sensitive_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.clients c
    join public.memberships m
      on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        (
          m.role in ('agency_admin','manager','compliance')
          and coalesce((auth.jwt()->>'aal')='aal2',false)
        )
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (
            c.office_id is null
            or m.office_id=c.office_id
          )
        )
      )
  )
$$;

revoke all on function app_private.can_view_sensitive_client(uuid)
from public, anon;
grant execute on function app_private.can_view_sensitive_client(uuid)
to authenticated;

create or replace function app_private.can_manage_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.clients c
    join public.memberships m
      on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        (
          m.role in ('agency_admin','manager')
          and coalesce((auth.jwt()->>'aal')='aal2',false)
        )
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (
            c.office_id is null
            or m.office_id=c.office_id
          )
        )
      )
  )
$$;

revoke all on function app_private.can_manage_client(uuid)
from public, anon;
grant execute on function app_private.can_manage_client(uuid)
to authenticated;

create or replace function app_private.can_view_internal_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.clients c
    join public.memberships m
      on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        (
          m.role in ('agency_admin','manager','compliance','revenue')
          and coalesce((auth.jwt()->>'aal')='aal2',false)
        )
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (
            c.office_id is null
            or m.office_id=c.office_id
          )
        )
      )
  )
$$;

revoke all on function app_private.can_view_internal_client(uuid)
from public, anon;
grant execute on function app_private.can_view_internal_client(uuid)
to authenticated;

create or replace function app_private.can_view_agency_sensitive_client(
  target_client uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.clients c
    join public.memberships m
      on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        (
          m.role in ('agency_admin','manager','compliance')
          and coalesce((auth.jwt()->>'aal')='aal2',false)
        )
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (
            c.office_id is null
            or m.office_id=c.office_id
          )
        )
      )
  )
$$;

revoke all on function app_private.can_view_agency_sensitive_client(uuid)
from public, anon;
grant execute on function app_private.can_view_agency_sensitive_client(uuid)
to authenticated;
