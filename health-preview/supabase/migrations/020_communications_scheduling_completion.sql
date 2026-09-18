-- 020_communications_scheduling_completion.sql
-- Completes communication endpoint, scheduling, booking, and automation runtime domains.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.contact_preferences
alter column client_id drop not null;

alter table public.contact_preferences
add column lead_id uuid references public.leads(id) on delete cascade;

alter table public.contact_preferences
add constraint contact_preferences_subject_chk
check ((client_id is not null)::int + (lead_id is not null)::int = 1);

create unique index contact_preferences_lead_uq
on public.contact_preferences(organization_id,lead_id)
where lead_id is not null;

create table public.communication_endpoints (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  provider_connection_id uuid references public.provider_connections(id) on delete set null,
  channel public.communication_channel not null,
  address text not null,
  external_id text,
  is_default boolean not null default false,
  inbound_enabled boolean not null default true,
  outbound_enabled boolean not null default true,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,channel,address)
);
create index communication_endpoints_org_idx on public.communication_endpoints(organization_id,channel,status);

create table public.scheduling_availability_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  day_of_week integer not null check(day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  timezone text not null default 'America/New_York',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(end_time > start_time)
);
create index scheduling_availability_user_idx on public.scheduling_availability_rules(organization_id,user_id,day_of_week,is_active);

create table public.booking_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  appointment_type_id uuid not null references public.appointment_types(id) on delete cascade,
  slug text not null,
  is_active boolean not null default true,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,slug)
);
create index booking_links_org_idx on public.booking_links(organization_id,is_active);

create table public.automation_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  rule_id uuid not null references public.automation_rules(id) on delete cascade,
  trigger_entity_type text,
  trigger_entity_id uuid,
  status text not null default 'queued',
  started_at timestamptz,
  finished_at timestamptz,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index automation_runs_rule_idx on public.automation_runs(organization_id,rule_id,created_at desc);

alter table public.communication_endpoints enable row level security;
alter table public.scheduling_availability_rules enable row level security;
alter table public.booking_links enable row level security;
alter table public.automation_runs enable row level security;

drop policy if exists contact_preferences_select on public.contact_preferences;
drop policy if exists contact_preferences_write on public.contact_preferences;

create policy contact_preferences_select on public.contact_preferences
for select to authenticated
using (
  (client_id is not null and (
    app_private.is_portal_user_for_client(client_id)
    or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
  ))
  or
  (lead_id is not null and exists(
    select 1 from public.leads l where l.id=lead_id and app_private.can_access_office(l.organization_id,l.office_id)
  ))
);

create policy contact_preferences_write on public.contact_preferences
for all to authenticated
using (
  (client_id is not null and (
    app_private.is_portal_user_for_client(client_id)
    or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
  ))
  or
  (lead_id is not null and exists(
    select 1 from public.leads l where l.id=lead_id and app_private.can_access_office(l.organization_id,l.office_id)
  ))
)
with check (
  (client_id is not null and (
    app_private.is_portal_user_for_client(client_id)
    or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
  ))
  or
  (lead_id is not null and exists(
    select 1 from public.leads l where l.id=lead_id and app_private.can_access_office(l.organization_id,l.office_id)
  ))
);

create policy communication_endpoints_select on public.communication_endpoints
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy communication_endpoints_write on public.communication_endpoints
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

create policy scheduling_availability_select on public.scheduling_availability_rules
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy scheduling_availability_write on public.scheduling_availability_rules
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and (
    user_id=(select auth.uid())
    or app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  )
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and (
    user_id=(select auth.uid())
    or app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  )
);

create policy booking_links_select on public.booking_links
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy booking_links_write on public.booking_links
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and (
    user_id=(select auth.uid())
    or app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  )
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and (
    user_id=(select auth.uid())
    or app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  )
);

create policy automation_runs_select on public.automation_runs
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
-- Automation runs are inserted/updated by trusted server workers only.

create trigger communication_endpoints_set_updated_at before update on public.communication_endpoints
for each row execute function public.set_updated_at();
create trigger scheduling_availability_set_updated_at before update on public.scheduling_availability_rules
for each row execute function public.set_updated_at();
create trigger booking_links_set_updated_at before update on public.booking_links
for each row execute function public.set_updated_at();

create trigger tenant_contact_preferences_lead_id
before insert or update on public.contact_preferences
for each row execute function app_private.guard_parent_organization('leads','lead_id');

create trigger tenant_communication_endpoints_office_id
before insert or update on public.communication_endpoints
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_communication_endpoints_provider_connection_id
before insert or update on public.communication_endpoints
for each row execute function app_private.guard_parent_organization('provider_connections','provider_connection_id');

create trigger tenant_scheduling_availability_office_id
before insert or update on public.scheduling_availability_rules
for each row execute function app_private.guard_parent_organization('offices','office_id');

create trigger tenant_booking_links_office_id
before insert or update on public.booking_links
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_booking_links_appointment_type_id
before insert or update on public.booking_links
for each row execute function app_private.guard_parent_organization('appointment_types','appointment_type_id');

create trigger tenant_automation_runs_rule_id
before insert or update on public.automation_runs
for each row execute function app_private.guard_parent_organization('automation_rules','rule_id');

create trigger userorg_communication_endpoints_user_id
before insert or update on public.communication_endpoints
for each row execute function app_private.guard_user_organization('user_id');
create trigger userorg_scheduling_availability_user_id
before insert or update on public.scheduling_availability_rules
for each row execute function app_private.guard_user_organization('user_id');
create trigger userorg_booking_links_user_id
before insert or update on public.booking_links
for each row execute function app_private.guard_user_organization('user_id');

create trigger audit_communication_endpoints after insert or update or delete on public.communication_endpoints
for each row execute function app_private.audit_row_change();
create trigger audit_scheduling_availability after insert or update or delete on public.scheduling_availability_rules
for each row execute function app_private.audit_row_change();
create trigger audit_booking_links after insert or update or delete on public.booking_links
for each row execute function app_private.audit_row_change();

grant select,insert,update,delete on public.communication_endpoints, public.scheduling_availability_rules, public.booking_links to authenticated;
grant select on public.automation_runs to authenticated;
