-- 010_office_access_hardening.sql
-- Enforces office-scoped agent access while preserving org-wide operational roles.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.can_access_office(target_org uuid, target_office uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.memberships m
    where m.user_id=(select auth.uid())
      and m.organization_id=target_org
      and m.is_active=true
      and (
        m.role = any(array['agency_admin','manager','compliance','revenue']::public.member_role[])
        or target_office is null
        or m.office_id=target_office
      )
  )
$$;

revoke all on function app_private.can_access_office(uuid,uuid) from public, anon;
grant execute on function app_private.can_access_office(uuid,uuid) to authenticated;

drop policy if exists leads_select on public.leads;
drop policy if exists leads_insert on public.leads;
drop policy if exists leads_update on public.leads;
create policy leads_select on public.leads for select to authenticated
using (app_private.can_access_office(organization_id,office_id));
create policy leads_insert on public.leads for insert to authenticated
with check (app_private.can_access_office(organization_id,office_id));
create policy leads_update on public.leads for update to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists clients_select on public.clients;
drop policy if exists clients_insert on public.clients;
drop policy if exists clients_update on public.clients;
create policy clients_select on public.clients for select to authenticated
using (app_private.can_access_office(organization_id,office_id));
create policy clients_insert on public.clients for insert to authenticated
with check (app_private.can_access_office(organization_id,office_id));
create policy clients_update on public.clients for update to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists appointments_select on public.appointments;
drop policy if exists appointments_all on public.appointments;
create policy appointments_all on public.appointments for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists enrollments_select on public.enrollments;
drop policy if exists enrollments_insert on public.enrollments;
drop policy if exists enrollments_update on public.enrollments;
create policy enrollments_select on public.enrollments for select to authenticated
using (app_private.can_access_office(organization_id,office_id));
create policy enrollments_insert on public.enrollments for insert to authenticated
with check (app_private.can_access_office(organization_id,office_id));
create policy enrollments_update on public.enrollments for update to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (
  app_private.can_access_office(organization_id,office_id)
  and not (
    lifecycle_status in ('submitted','pending','approved','active')
    and app_private.has_org_role(organization_id,array['revenue']::public.member_role[])
  )
);

drop policy if exists policies_select on public.policies;
drop policy if exists policies_write on public.policies;
create policy policies_select on public.policies for select to authenticated
using (app_private.can_access_office(organization_id,office_id));
create policy policies_write on public.policies for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[])
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[])
);

drop policy if exists service_requests_select on public.service_requests;
drop policy if exists service_requests_all on public.service_requests;
create policy service_requests_all on public.service_requests for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists renewals_select on public.renewals;
drop policy if exists renewals_all on public.renewals;
create policy renewals_all on public.renewals for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists communication_threads_select on public.communication_threads;
drop policy if exists communication_threads_all on public.communication_threads;
create policy communication_threads_all on public.communication_threads for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists communications_select on public.communications;
drop policy if exists communications_all on public.communications;
create policy communications_all on public.communications for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists documents_select on public.documents;
drop policy if exists documents_all on public.documents;
create policy documents_all on public.documents for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists tasks_select on public.tasks;
drop policy if exists tasks_all on public.tasks;
create policy tasks_all on public.tasks for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

drop policy if exists provider_connections_select on public.provider_connections;
drop policy if exists provider_connections_write on public.provider_connections;
create policy provider_connections_select on public.provider_connections
for select to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);
create policy provider_connections_write on public.provider_connections
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
);

-- Child records inherit the office scope of their parent client/enrollment/policy.
drop policy if exists households_select on public.households;
drop policy if exists households_write on public.households;
create policy households_all on public.households for all to authenticated
using (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)))
with check (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)));

drop policy if exists household_members_select on public.household_members;
drop policy if exists household_members_write on public.household_members;
create policy household_members_all on public.household_members for all to authenticated
using (exists(
  select 1 from public.households h join public.clients c on c.id=h.client_id
  where h.id=household_id and app_private.can_access_office(c.organization_id,c.office_id)
))
with check (exists(
  select 1 from public.households h join public.clients c on c.id=h.client_id
  where h.id=household_id and app_private.can_access_office(c.organization_id,c.office_id)
));

drop policy if exists enrollment_evidence_select on public.enrollment_evidence;
drop policy if exists enrollment_evidence_all on public.enrollment_evidence;
create policy enrollment_evidence_all on public.enrollment_evidence for all to authenticated
using (exists(select 1 from public.enrollments e where e.id=enrollment_id and app_private.can_access_office(e.organization_id,e.office_id)))
with check (exists(select 1 from public.enrollments e where e.id=enrollment_id and app_private.can_access_office(e.organization_id,e.office_id)));

drop policy if exists consent_records_select on public.consent_records;
drop policy if exists consent_records_all on public.consent_records;
create policy consent_records_all on public.consent_records for all to authenticated
using (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)))
with check (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)));

drop policy if exists policy_events_select on public.policy_events;
drop policy if exists policy_events_insert on public.policy_events;
create policy policy_events_select on public.policy_events for select to authenticated
using (exists(select 1 from public.policies p where p.id=policy_id and app_private.can_access_office(p.organization_id,p.office_id)));
create policy policy_events_insert on public.policy_events for insert to authenticated
with check (exists(select 1 from public.policies p where p.id=policy_id and app_private.can_access_office(p.organization_id,p.office_id)));

drop policy if exists portal_invitations_select on public.portal_invitations;
drop policy if exists portal_invitations_write on public.portal_invitations;
create policy portal_invitations_select on public.portal_invitations for select to authenticated
using (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)));
create policy portal_invitations_write on public.portal_invitations for all to authenticated
using (
  exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
  and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[])
)
with check (
  exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
  and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[])
);
