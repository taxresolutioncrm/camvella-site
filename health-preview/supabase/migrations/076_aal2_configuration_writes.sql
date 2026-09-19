-- 076_aal2_configuration_writes.sql
-- Enforces AAL2 at the database boundary for management configuration mutations.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists communication_endpoints_write on public.communication_endpoints;
create policy communication_endpoints_write on public.communication_endpoints
for all to authenticated
using (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
);

drop policy if exists appointment_types_write on public.appointment_types;
create policy appointment_types_write on public.appointment_types
for all to authenticated
using (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
);

drop policy if exists communication_templates_write on public.communication_templates;
create policy communication_templates_write on public.communication_templates
for all to authenticated
using (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
);

drop policy if exists automation_rules_write on public.automation_rules;
create policy automation_rules_write on public.automation_rules
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
);

drop policy if exists public_intake_forms_write on public.public_intake_forms;
create policy public_intake_forms_write on public.public_intake_forms
for all to authenticated
using (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
);

drop policy if exists outreach_campaigns_write on public.outreach_campaigns;
create policy outreach_campaigns_write on public.outreach_campaigns
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager']::public.member_role[]
  )
);

-- Agents may maintain only their own scheduling/link records at AAL1.
-- Management mutations require AAL2.
drop policy if exists scheduling_availability_write on public.scheduling_availability_rules;
create policy scheduling_availability_write on public.scheduling_availability_rules
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and (
    (
      user_id=(select auth.uid())
      and app_private.has_org_role(
        organization_id,
        array['agent']::public.member_role[]
      )
    )
    or (
      app_private.has_aal2()
      and app_private.has_org_role(
        organization_id,
        array['agency_admin','manager']::public.member_role[]
      )
    )
  )
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and (
    (
      user_id=(select auth.uid())
      and app_private.has_org_role(
        organization_id,
        array['agent']::public.member_role[]
      )
    )
    or (
      app_private.has_aal2()
      and app_private.has_org_role(
        organization_id,
        array['agency_admin','manager']::public.member_role[]
      )
    )
  )
);

drop policy if exists booking_links_write on public.booking_links;
create policy booking_links_write on public.booking_links
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and (
    (
      user_id=(select auth.uid())
      and app_private.has_org_role(
        organization_id,
        array['agent']::public.member_role[]
      )
    )
    or (
      app_private.has_aal2()
      and app_private.has_org_role(
        organization_id,
        array['agency_admin','manager']::public.member_role[]
      )
    )
  )
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and (
    (
      user_id=(select auth.uid())
      and app_private.has_org_role(
        organization_id,
        array['agent']::public.member_role[]
      )
    )
    or (
      app_private.has_aal2()
      and app_private.has_org_role(
        organization_id,
        array['agency_admin','manager']::public.member_role[]
      )
    )
  )
);
