-- 003_rls.sql
-- Migration-ready draft. DO NOT APPLY until dedicated Supabase project is selected.

create schema if not exists app_private;

create or replace function app_private.current_org_ids()
returns setof uuid
language sql
stable
security invoker
set search_path = public, auth
as $$
  select m.organization_id
  from public.memberships m
  where m.user_id = (select auth.uid())
    and m.is_active = true
$$;

create or replace function app_private.has_org_role(target_org uuid, allowed public.member_role[])
returns boolean
language sql
stable
security invoker
set search_path = public, auth
as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = (select auth.uid())
      and m.organization_id = target_org
      and m.is_active = true
      and m.role = any(allowed)
  )
$$;

revoke all on schema app_private from public, anon, authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.current_org_ids() to authenticated;
grant execute on function app_private.has_org_role(uuid, public.member_role[]) to authenticated;

-- Enable RLS everywhere exposed.
alter table public.organizations enable row level security;
alter table public.offices enable row level security;
alter table public.memberships enable row level security;
alter table public.leads enable row level security;
alter table public.clients enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.appointments enable row level security;
alter table public.carriers enable row level security;
alter table public.carrier_products enable row level security;
alter table public.enrollments enable row level security;
alter table public.enrollment_evidence enable row level security;
alter table public.policies enable row level security;
alter table public.policy_events enable row level security;
alter table public.service_requests enable row level security;
alter table public.renewals enable row level security;
alter table public.communication_threads enable row level security;
alter table public.communications enable row level security;
alter table public.documents enable row level security;
alter table public.consent_records enable row level security;
alter table public.tasks enable row level security;
alter table public.carrier_contracts enable row level security;
alter table public.commission_statements enable row level security;
alter table public.commission_lines enable row level security;
alter table public.commission_exceptions enable row level security;
alter table public.audit_log enable row level security;

-- Generic tenant SELECT policy factory pattern expanded explicitly where needed.
create policy organizations_select on public.organizations
for select to authenticated
using (id in (select app_private.current_org_ids()));

create policy offices_select on public.offices
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy memberships_select on public.memberships
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and (
    user_id = (select auth.uid())
    or app_private.has_org_role(organization_id, array['agency_admin','manager']::public.member_role[])
  )
);

create policy memberships_write on public.memberships
for all to authenticated
using (app_private.has_org_role(organization_id, array['agency_admin']::public.member_role[]))
with check (app_private.has_org_role(organization_id, array['agency_admin']::public.member_role[]));

-- Reusable tenant tables: members of the org can read.
create policy leads_select on public.leads for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy clients_select on public.clients for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy households_select on public.households for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy household_members_select on public.household_members for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy appointments_select on public.appointments for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy carriers_select on public.carriers for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy carrier_products_select on public.carrier_products for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy enrollments_select on public.enrollments for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy enrollment_evidence_select on public.enrollment_evidence for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy policies_select on public.policies for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy policy_events_select on public.policy_events for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy service_requests_select on public.service_requests for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy renewals_select on public.renewals for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy communication_threads_select on public.communication_threads for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy communications_select on public.communications for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy documents_select on public.documents for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy consent_records_select on public.consent_records for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy tasks_select on public.tasks for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy carrier_contracts_select on public.carrier_contracts for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy commission_statements_select on public.commission_statements for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy commission_lines_select on public.commission_lines for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy commission_exceptions_select on public.commission_exceptions for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy audit_log_select on public.audit_log for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','compliance']::public.member_role[])
);

-- Operational writes.
create policy leads_insert on public.leads for insert to authenticated
with check (organization_id in (select app_private.current_org_ids()));
create policy leads_update on public.leads for update to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy clients_insert on public.clients for insert to authenticated
with check (organization_id in (select app_private.current_org_ids()));
create policy clients_update on public.clients for update to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy appointments_all on public.appointments for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy enrollments_insert on public.enrollments for insert to authenticated
with check (organization_id in (select app_private.current_org_ids()));
create policy enrollments_update on public.enrollments for update to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (
  organization_id in (select app_private.current_org_ids())
  and not (
    lifecycle_status in ('submitted','pending','approved','active')
    and app_private.has_org_role(organization_id, array['revenue']::public.member_role[])
  )
);

create policy enrollment_evidence_all on public.enrollment_evidence for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy policies_write on public.policies for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','agent']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','agent']::public.member_role[])
);

create policy service_requests_all on public.service_requests for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy renewals_all on public.renewals for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy communication_threads_all on public.communication_threads for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy communications_all on public.communications for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy documents_all on public.documents for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy consent_records_all on public.consent_records for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy tasks_all on public.tasks for all to authenticated
using (organization_id in (select app_private.current_org_ids()))
with check (organization_id in (select app_private.current_org_ids()));

create policy carrier_contracts_write on public.carrier_contracts for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','compliance']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','compliance']::public.member_role[])
);

create policy commission_statements_write on public.commission_statements for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','revenue']::public.member_role[])
);

create policy commission_lines_write on public.commission_lines for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','revenue']::public.member_role[])
);

create policy commission_exceptions_write on public.commission_exceptions for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','revenue']::public.member_role[])
);

-- Audit log is append-only for authenticated org members.
create policy audit_log_insert on public.audit_log for insert to authenticated
with check (organization_id in (select app_private.current_org_ids()));

revoke update, delete on public.audit_log from authenticated;
