-- 032_external_ids_and_sync_jobs.sql
-- Durable provider identifiers and resumable integration sync jobs.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.enrollments
add column external_source text,
add column external_application_id text,
add column external_enrollment_id text,
add column external_status text,
add column last_synced_at timestamptz;

create unique index enrollments_external_id_uq
on public.enrollments(organization_id,external_source,external_enrollment_id)
where external_source is not null and external_enrollment_id is not null;

alter table public.policies
add column external_source text,
add column external_policy_id text,
add column last_synced_at timestamptz;

create unique index policies_external_id_uq
on public.policies(organization_id,external_source,external_policy_id)
where external_source is not null and external_policy_id is not null;

alter table public.appointments
add column external_calendar_provider text,
add column external_calendar_event_id text;

create unique index appointments_external_calendar_uq
on public.appointments(organization_id,external_calendar_provider,external_calendar_event_id)
where external_calendar_provider is not null and external_calendar_event_id is not null;

alter table public.carrier_contracts
add column last_synced_at timestamptz;

create table public.integration_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provider_connection_id uuid not null references public.provider_connections(id) on delete cascade,
  sync_type text not null,
  status text not null default 'queued',
  cursor_in text,
  cursor_out text,
  records_seen integer not null default 0 check(records_seen>=0),
  records_changed integer not null default 0 check(records_changed>=0),
  started_at timestamptz,
  finished_at timestamptz,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index integration_sync_jobs_org_status_idx
on public.integration_sync_jobs(organization_id,status,created_at desc);

alter table public.integration_sync_jobs enable row level security;

create policy integration_sync_jobs_select on public.integration_sync_jobs
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);
-- Writes are server-worker only.

create trigger tenant_integration_sync_jobs_provider_connection_id
before insert or update on public.integration_sync_jobs
for each row execute function app_private.guard_parent_organization('provider_connections','provider_connection_id');

grant select on public.integration_sync_jobs to authenticated;
