-- 022_role_policy_alignment.sql
-- Aligns database authorization with the CRM's visible role matrix.
-- DO NOT APPLY until the dedicated Supabase project is selected.

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
  select exists (
    select 1 from public.memberships m
    where m.user_id=(select auth.uid())
      and m.organization_id=target_org
      and m.is_active=true
      and (
        m.role in ('agency_admin','manager')
        or (
          m.role='agent'
          and target_assigned_user=(select auth.uid())
          and (target_office is null or m.office_id=target_office)
        )
      )
  )
$$;
revoke all on function app_private.can_manage_assignment(uuid,uuid,uuid) from public, anon;
grant execute on function app_private.can_manage_assignment(uuid,uuid,uuid) to authenticated;

create or replace function app_private.can_view_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    exists(
      select 1 from public.client_portal_accounts p
      where p.client_id=target_client
        and p.user_id=(select auth.uid())
        and p.status='active'
    )
    or exists(
      select 1
      from public.clients c
      join public.memberships m on m.organization_id=c.organization_id
      where c.id=target_client
        and m.user_id=(select auth.uid())
        and m.is_active=true
        and (
          m.role in ('agency_admin','manager','compliance','revenue')
          or (
            m.role='agent'
            and c.assigned_user_id=(select auth.uid())
            and (c.office_id is null or m.office_id=c.office_id)
          )
        )
    )
$$;
revoke all on function app_private.can_view_client(uuid) from public, anon;
grant execute on function app_private.can_view_client(uuid) to authenticated;

create or replace function app_private.can_view_sensitive_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    exists(
      select 1 from public.client_portal_accounts p
      where p.client_id=target_client
        and p.user_id=(select auth.uid())
        and p.status='active'
    )
    or exists(
      select 1
      from public.clients c
      join public.memberships m on m.organization_id=c.organization_id
      where c.id=target_client
        and m.user_id=(select auth.uid())
        and m.is_active=true
        and (
          m.role in ('agency_admin','manager','compliance')
          or (
            m.role='agent'
            and c.assigned_user_id=(select auth.uid())
            and (c.office_id is null or m.office_id=c.office_id)
          )
        )
    )
$$;
revoke all on function app_private.can_view_sensitive_client(uuid) from public, anon;
grant execute on function app_private.can_view_sensitive_client(uuid) to authenticated;

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
    join public.memberships m on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        m.role in ('agency_admin','manager')
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (c.office_id is null or m.office_id=c.office_id)
        )
      )
  )
$$;
revoke all on function app_private.can_manage_client(uuid) from public, anon;
grant execute on function app_private.can_manage_client(uuid) to authenticated;

-- Leads: admin/manager or assigned agent.
drop policy if exists leads_select on public.leads;
drop policy if exists leads_insert on public.leads;
drop policy if exists leads_update on public.leads;
create policy leads_select on public.leads for select to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or (
    assigned_user_id=(select auth.uid())
    and app_private.can_access_office(organization_id,office_id)
    and app_private.has_org_role(organization_id,array['agent']::public.member_role[])
  )
);
create policy leads_insert on public.leads for insert to authenticated
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));
create policy leads_update on public.leads for update to authenticated
using (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id))
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));

-- Clients: revenue/compliance may read; only admin/manager/assigned agent may write.
drop policy if exists clients_select on public.clients;
drop policy if exists clients_insert on public.clients;
drop policy if exists clients_update on public.clients;
create policy clients_select on public.clients for select to authenticated
using (app_private.can_view_client(id));
create policy clients_insert on public.clients for insert to authenticated
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));
create policy clients_update on public.clients for update to authenticated
using (app_private.can_manage_client(id))
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));

-- Sensitive household data.
drop policy if exists households_all on public.households;
create policy households_select on public.households for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy households_write on public.households for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

drop policy if exists household_members_all on public.household_members;
create policy household_members_select on public.household_members for select to authenticated
using (exists(select 1 from public.households h where h.id=household_id and app_private.can_view_sensitive_client(h.client_id)));
create policy household_members_write on public.household_members for all to authenticated
using (exists(select 1 from public.households h where h.id=household_id and app_private.can_manage_client(h.client_id)))
with check (exists(select 1 from public.households h where h.id=household_id and app_private.can_manage_client(h.client_id)));

-- Appointments.
drop policy if exists appointments_all on public.appointments;
create policy appointments_select on public.appointments for select to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
  or (
    assigned_user_id=(select auth.uid())
    and app_private.has_org_role(organization_id,array['agent']::public.member_role[])
    and app_private.can_access_office(organization_id,office_id)
  )
);
create policy appointments_write on public.appointments for all to authenticated
using (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id))
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));

-- Enrollments and evidence.
drop policy if exists enrollments_select on public.enrollments;
drop policy if exists enrollments_insert on public.enrollments;
drop policy if exists enrollments_update on public.enrollments;
create policy enrollments_select on public.enrollments for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy enrollments_insert on public.enrollments for insert to authenticated
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));
create policy enrollments_update on public.enrollments for update to authenticated
using (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id))
with check (app_private.can_manage_assignment(organization_id,office_id,assigned_user_id));

drop policy if exists enrollment_evidence_all on public.enrollment_evidence;
create policy enrollment_evidence_select on public.enrollment_evidence for select to authenticated
using (exists(select 1 from public.enrollments e where e.id=enrollment_id and app_private.can_view_client(e.client_id)));
create policy enrollment_evidence_write on public.enrollment_evidence for all to authenticated
using (
  exists(select 1 from public.enrollments e where e.id=enrollment_id and (
    app_private.can_manage_client(e.client_id)
    or app_private.has_org_role(e.organization_id,array['compliance']::public.member_role[])
  ))
)
with check (
  exists(select 1 from public.enrollments e where e.id=enrollment_id and (
    app_private.can_manage_client(e.client_id)
    or app_private.has_org_role(e.organization_id,array['compliance']::public.member_role[])
  ))
);

-- Policies and renewals.
drop policy if exists policies_select on public.policies;
drop policy if exists policies_write on public.policies;
create policy policies_select on public.policies for select to authenticated
using (app_private.can_view_client(client_id));
create policy policies_write on public.policies for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

drop policy if exists renewals_all on public.renewals;
create policy renewals_select on public.renewals for select to authenticated
using (app_private.can_view_client(client_id));
create policy renewals_write on public.renewals for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

-- Service requests: client portal can submit/read own; agency write is admin/manager/assigned agent.
drop policy if exists service_requests_select on public.service_requests;
drop policy if exists service_requests_insert on public.service_requests;
drop policy if exists service_requests_update on public.service_requests;
drop policy if exists service_requests_delete on public.service_requests;
create policy service_requests_select on public.service_requests for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy service_requests_insert on public.service_requests for insert to authenticated
with check (
  app_private.is_portal_user_for_client(client_id)
  or app_private.can_manage_client(client_id)
);
create policy service_requests_update on public.service_requests for update to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));
create policy service_requests_delete on public.service_requests for delete to authenticated
using (app_private.can_manage_client(client_id));

-- Communications: revenue does not get client communications.
drop policy if exists communication_threads_all on public.communication_threads;
create policy communication_threads_select on public.communication_threads for select to authenticated
using (
  (client_id is not null and app_private.can_view_sensitive_client(client_id))
  or (
    client_id is null
    and (
      app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
      or (assigned_user_id=(select auth.uid()) and app_private.has_org_role(organization_id,array['agent']::public.member_role[]))
    )
  )
);
create policy communication_threads_write on public.communication_threads for all to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or (assigned_user_id=(select auth.uid()) and app_private.has_org_role(organization_id,array['agent']::public.member_role[]))
)
with check (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or (assigned_user_id=(select auth.uid()) and app_private.has_org_role(organization_id,array['agent']::public.member_role[]))
);

drop policy if exists communications_all on public.communications;
create policy communications_select on public.communications for select to authenticated
using (
  (client_id is not null and app_private.can_view_sensitive_client(client_id))
  or (
    client_id is null and (
      app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
      or (user_id=(select auth.uid()) and app_private.has_org_role(organization_id,array['agent']::public.member_role[]))
    )
  )
);
create policy communications_write on public.communications for all to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or (user_id=(select auth.uid()) and app_private.has_org_role(organization_id,array['agent']::public.member_role[]))
)
with check (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or (user_id=(select auth.uid()) and app_private.has_org_role(organization_id,array['agent']::public.member_role[]))
);

-- Documents: compliance can manage evidence documents; revenue cannot read client documents.
drop policy if exists documents_select on public.documents;
drop policy if exists documents_insert on public.documents;
drop policy if exists documents_update on public.documents;
drop policy if exists documents_delete on public.documents;
create policy documents_select on public.documents for select to authenticated
using (
  (client_id is not null and app_private.can_view_sensitive_client(client_id))
  or (
    client_id is null
    and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
  )
);
create policy documents_insert on public.documents for insert to authenticated
with check (
  (client_id is not null and app_private.is_portal_user_for_client(client_id))
  or (client_id is not null and app_private.can_manage_client(client_id))
  or app_private.has_org_role(organization_id,array['compliance']::public.member_role[])
);
create policy documents_update on public.documents for update to authenticated
using (
  (client_id is not null and app_private.can_manage_client(client_id))
  or app_private.has_org_role(organization_id,array['compliance']::public.member_role[])
)
with check (
  (client_id is not null and app_private.can_manage_client(client_id))
  or app_private.has_org_role(organization_id,array['compliance']::public.member_role[])
);
create policy documents_delete on public.documents for delete to authenticated
using (
  (client_id is not null and app_private.can_manage_client(client_id))
  or app_private.has_org_role(organization_id,array['compliance']::public.member_role[])
);

-- Consent metadata: revenue may read; compliance can write.
drop policy if exists consent_records_all on public.consent_records;
create policy consent_records_select on public.consent_records for select to authenticated
using (app_private.can_view_client(client_id));
create policy consent_records_write on public.consent_records for all to authenticated
using (
  app_private.can_manage_client(client_id)
  or app_private.has_org_role(organization_id,array['compliance']::public.member_role[])
)
with check (
  app_private.can_manage_client(client_id)
  or app_private.has_org_role(organization_id,array['compliance']::public.member_role[])
);

-- Commission access: manager read, revenue/admin full, agent own lines/exceptions.
drop policy if exists commission_statements_select on public.commission_statements;
drop policy if exists commission_statements_write on public.commission_statements;
create policy commission_statements_select on public.commission_statements for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','revenue']::public.member_role[])
);
create policy commission_statements_write on public.commission_statements for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
);

drop policy if exists commission_lines_select on public.commission_lines;
drop policy if exists commission_lines_write on public.commission_lines;
create policy commission_lines_select on public.commission_lines for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and (
    app_private.has_org_role(organization_id,array['agency_admin','manager','revenue']::public.member_role[])
    or (
      user_id=(select auth.uid())
      and app_private.has_org_role(organization_id,array['agent']::public.member_role[])
    )
  )
);
create policy commission_lines_write on public.commission_lines for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
);

drop policy if exists commission_exceptions_select on public.commission_exceptions;
drop policy if exists commission_exceptions_write on public.commission_exceptions;
create policy commission_exceptions_select on public.commission_exceptions for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and (
    app_private.has_org_role(organization_id,array['agency_admin','manager','revenue']::public.member_role[])
    or exists(
      select 1 from public.commission_lines cl
      where cl.id=commission_line_id
        and cl.user_id=(select auth.uid())
        and app_private.has_org_role(organization_id,array['agent']::public.member_role[])
    )
  )
);
create policy commission_exceptions_write on public.commission_exceptions for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
);

-- Sensitive doctors/Rx/pharmacy and comparisons.
drop policy if exists client_providers_select on public.client_providers;
drop policy if exists client_providers_write on public.client_providers;
create policy client_providers_select on public.client_providers for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy client_providers_write on public.client_providers for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

drop policy if exists client_prescriptions_select on public.client_prescriptions;
drop policy if exists client_prescriptions_write on public.client_prescriptions;
create policy client_prescriptions_select on public.client_prescriptions for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy client_prescriptions_write on public.client_prescriptions for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

drop policy if exists client_pharmacies_select on public.client_pharmacies;
drop policy if exists client_pharmacies_write on public.client_pharmacies;
create policy client_pharmacies_select on public.client_pharmacies for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy client_pharmacies_write on public.client_pharmacies for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

drop policy if exists plan_comparisons_select on public.plan_comparisons;
drop policy if exists plan_comparisons_write on public.plan_comparisons;
create policy plan_comparisons_select on public.plan_comparisons for select to authenticated
using (app_private.can_view_sensitive_client(client_id));
create policy plan_comparisons_write on public.plan_comparisons for all to authenticated
using (app_private.can_manage_client(client_id))
with check (app_private.can_manage_client(client_id));

drop policy if exists plan_comparison_items_select on public.plan_comparison_items;
drop policy if exists plan_comparison_items_write on public.plan_comparison_items;
create policy plan_comparison_items_select on public.plan_comparison_items for select to authenticated
using (exists(select 1 from public.plan_comparisons pc where pc.id=comparison_id and app_private.can_view_sensitive_client(pc.client_id)));
create policy plan_comparison_items_write on public.plan_comparison_items for all to authenticated
using (exists(select 1 from public.plan_comparisons pc where pc.id=comparison_id and app_private.can_manage_client(pc.client_id)))
with check (exists(select 1 from public.plan_comparisons pc where pc.id=comparison_id and app_private.can_manage_client(pc.client_id)));

-- Licensing / carrier readiness: self read or management/compliance.
drop policy if exists agent_licenses_select on public.agent_licenses;
drop policy if exists agent_licenses_write on public.agent_licenses;
create policy agent_licenses_select on public.agent_licenses for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and (
    user_id=(select auth.uid())
    or app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
  )
);
create policy agent_licenses_write on public.agent_licenses for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
);

drop policy if exists carrier_contracts_select on public.carrier_contracts;
drop policy if exists carrier_contracts_write on public.carrier_contracts;
create policy carrier_contracts_select on public.carrier_contracts for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and (
    user_id=(select auth.uid())
    or app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
  )
);
create policy carrier_contracts_write on public.carrier_contracts for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
);
