-- 005_platform_support.sql
-- Final pre-backend support layer. DO NOT APPLY until dedicated Supabase project is selected.

create table public.provider_connections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete cascade,
  provider_type text not null,
  provider_name text not null,
  external_account_id text,
  status text not null default 'disconnected',
  config_public jsonb not null default '{}'::jsonb,
  secret_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id, office_id, provider_type, provider_name)
);
create index provider_connections_org_idx on public.provider_connections(organization_id);

create table public.provider_event_ledger (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  payload_version text,
  signature_valid boolean not null default false,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received',
  normalized_entity_type text,
  normalized_entity_id uuid,
  raw_payload_ref text,
  unique(provider, provider_event_id)
);
create index provider_event_ledger_org_idx on public.provider_event_ledger(organization_id);
create index provider_event_ledger_status_idx on public.provider_event_ledger(processing_status,received_at);

alter table public.provider_connections enable row level security;
alter table public.provider_event_ledger enable row level security;

create policy provider_connections_select on public.provider_connections
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager']::public.member_role[])
);

create policy provider_connections_write on public.provider_connections
for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin']::public.member_role[])
);

-- Provider event ledger is server-ingest only. No authenticated write policy.
create policy provider_event_ledger_select on public.provider_event_ledger
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id, array['agency_admin','manager','compliance']::public.member_role[])
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger leads_set_updated_at before update on public.leads
for each row execute function public.set_updated_at();
create trigger clients_set_updated_at before update on public.clients
for each row execute function public.set_updated_at();
create trigger enrollments_set_updated_at before update on public.enrollments
for each row execute function public.set_updated_at();
create trigger policies_set_updated_at before update on public.policies
for each row execute function public.set_updated_at();
create trigger carrier_contracts_set_updated_at before update on public.carrier_contracts
for each row execute function public.set_updated_at();
create trigger provider_connections_set_updated_at before update on public.provider_connections
for each row execute function public.set_updated_at();

create view public.v_open_enrollment_queue
with (security_invoker = true)
as
select
  e.id,
  e.organization_id,
  e.office_id,
  e.client_id,
  c.first_name,
  c.last_name,
  e.market,
  e.lifecycle_status,
  e.assigned_user_id,
  e.updated_at
from public.enrollments e
join public.clients c on c.id = e.client_id
where e.lifecycle_status not in ('active','denied','cancelled');

create view public.v_commission_exception_queue
with (security_invoker = true)
as
select
  ce.id,
  ce.organization_id,
  ce.reason,
  ce.amount,
  ce.status,
  ce.assigned_user_id,
  cl.statement_id,
  cl.policy_id,
  cl.client_id,
  ce.created_at
from public.commission_exceptions ce
join public.commission_lines cl on cl.id = ce.commission_line_id
where ce.status <> 'resolved';

create view public.v_renewal_queue
with (security_invoker = true)
as
select
  r.id,
  r.organization_id,
  r.office_id,
  r.client_id,
  c.first_name,
  c.last_name,
  r.market,
  r.review_window_start,
  r.review_window_end,
  r.risk_level,
  r.outreach_status
from public.renewals r
join public.clients c on c.id = r.client_id;

grant select on public.v_open_enrollment_queue to authenticated;
grant select on public.v_commission_exception_queue to authenticated;
grant select on public.v_renewal_queue to authenticated;
