-- 085_agent_configuration_read_scope.sql
-- Agents see only their own/shared office runtime configuration; management remains organization-wide.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists communication_endpoints_select on public.communication_endpoints;
create policy communication_endpoints_select on public.communication_endpoints
for select to authenticated
using (
  app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
  or exists(
    select 1
    from public.memberships m
    where m.organization_id=communication_endpoints.organization_id
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and m.role='agent'
      and (
        communication_endpoints.user_id=(select auth.uid())
        or (
          communication_endpoints.user_id is null
          and (
            communication_endpoints.office_id is null
            or communication_endpoints.office_id=m.office_id
          )
        )
      )
  )
);

drop policy if exists scheduling_availability_select
on public.scheduling_availability_rules;
create policy scheduling_availability_select
on public.scheduling_availability_rules
for select to authenticated
using (
  app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
  or (
    user_id=(select auth.uid())
    and app_private.has_org_role(
      organization_id,
      array['agent']::public.member_role[]
    )
  )
);

drop policy if exists booking_links_select on public.booking_links;
create policy booking_links_select on public.booking_links
for select to authenticated
using (
  app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
  or (
    user_id=(select auth.uid())
    and app_private.has_org_role(
      organization_id,
      array['agent']::public.member_role[]
    )
  )
);

drop policy if exists public_intake_forms_select on public.public_intake_forms;
create policy public_intake_forms_select on public.public_intake_forms
for select to authenticated
using (
  app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
  or (
    assigned_user_id=(select auth.uid())
    and app_private.has_org_role(
      organization_id,
      array['agent']::public.member_role[]
    )
  )
);
