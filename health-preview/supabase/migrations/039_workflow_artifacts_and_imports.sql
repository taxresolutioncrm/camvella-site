-- 039_workflow_artifacts_and_imports.sql
-- Adds evidence bundles, outreach campaigns, and import job tracking used by current UI.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create table public.evidence_bundles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  status text not null default 'draft',
  snapshot jsonb not null default '{}'::jsonb,
  storage_path text,
  generated_by uuid references auth.users(id) on delete set null,
  generated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,enrollment_id)
);
create index evidence_bundles_org_idx on public.evidence_bundles(organization_id,status);

create table public.outreach_campaigns (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  name text not null,
  market public.market_type,
  channel public.communication_channel,
  audience_filter jsonb not null default '{}'::jsonb,
  status text not null default 'draft',
  scheduled_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index outreach_campaigns_org_idx on public.outreach_campaigns(organization_id,status,scheduled_at);

create table public.outreach_campaign_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  campaign_id uuid not null references public.outreach_campaigns(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  renewal_id uuid references public.renewals(id) on delete set null,
  status text not null default 'queued',
  last_contact_at timestamptz,
  created_at timestamptz not null default now(),
  unique(campaign_id,client_id)
);
create index outreach_campaign_members_campaign_idx on public.outreach_campaign_members(campaign_id,status);

create table public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  import_type text not null,
  source_filename text not null,
  storage_path text not null,
  status text not null default 'uploaded',
  rows_total integer not null default 0 check(rows_total>=0),
  rows_valid integer not null default 0 check(rows_valid>=0),
  rows_imported integer not null default 0 check(rows_imported>=0),
  rows_failed integer not null default 0 check(rows_failed>=0),
  error_summary jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index import_jobs_org_idx on public.import_jobs(organization_id,import_type,status,created_at desc);

alter table public.evidence_bundles enable row level security;
alter table public.outreach_campaigns enable row level security;
alter table public.outreach_campaign_members enable row level security;
alter table public.import_jobs enable row level security;

create policy evidence_bundles_select on public.evidence_bundles
for select to authenticated
using (
  exists(
    select 1 from public.enrollments e
    where e.id=enrollment_id
      and app_private.can_view_agency_sensitive_client(e.client_id)
  )
);

create policy evidence_bundles_write on public.evidence_bundles
for all to authenticated
using (
  exists(
    select 1 from public.enrollments e
    where e.id=enrollment_id
      and (
        app_private.can_manage_client(e.client_id)
        or app_private.has_org_role(e.organization_id,array['compliance']::public.member_role[])
      )
  )
)
with check (
  exists(
    select 1 from public.enrollments e
    where e.id=enrollment_id
      and (
        app_private.can_manage_client(e.client_id)
        or app_private.has_org_role(e.organization_id,array['compliance']::public.member_role[])
      )
  )
);

create policy outreach_campaigns_select on public.outreach_campaigns
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[])
);

create policy outreach_campaigns_write on public.outreach_campaigns
for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

create policy outreach_campaign_members_select on public.outreach_campaign_members
for select to authenticated
using (
  exists(
    select 1 from public.outreach_campaigns oc
    where oc.id=campaign_id
      and oc.organization_id in (select app_private.current_org_ids())
      and app_private.has_org_role(oc.organization_id,array['agency_admin','manager','agent']::public.member_role[])
  )
);

create policy outreach_campaign_members_write on public.outreach_campaign_members
for all to authenticated
using (
  exists(
    select 1 from public.outreach_campaigns oc
    where oc.id=campaign_id
      and app_private.has_org_role(oc.organization_id,array['agency_admin','manager']::public.member_role[])
  )
)
with check (
  exists(
    select 1 from public.outreach_campaigns oc
    where oc.id=campaign_id
      and app_private.has_org_role(oc.organization_id,array['agency_admin','manager']::public.member_role[])
  )
);

create policy import_jobs_select on public.import_jobs
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','revenue']::public.member_role[])
);

create policy import_jobs_write on public.import_jobs
for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','revenue']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','revenue']::public.member_role[])
);

create trigger evidence_bundles_set_updated_at before update on public.evidence_bundles
for each row execute function public.set_updated_at();
create trigger outreach_campaigns_set_updated_at before update on public.outreach_campaigns
for each row execute function public.set_updated_at();

create trigger tenant_evidence_bundles_enrollment_id
before insert or update on public.evidence_bundles
for each row execute function app_private.guard_parent_organization('enrollments','enrollment_id');

create trigger tenant_outreach_campaigns_office_id
before insert or update on public.outreach_campaigns
for each row execute function app_private.guard_parent_organization('offices','office_id');

create trigger tenant_outreach_campaign_members_campaign_id
before insert or update on public.outreach_campaign_members
for each row execute function app_private.guard_parent_organization('outreach_campaigns','campaign_id');
create trigger tenant_outreach_campaign_members_client_id
before insert or update on public.outreach_campaign_members
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_outreach_campaign_members_renewal_id
before insert or update on public.outreach_campaign_members
for each row execute function app_private.guard_parent_organization('renewals','renewal_id');

create trigger tenant_import_jobs_office_id
before insert or update on public.import_jobs
for each row execute function app_private.guard_parent_organization('offices','office_id');

create trigger userorg_evidence_bundles_generated_by
before insert or update on public.evidence_bundles
for each row execute function app_private.guard_user_organization('generated_by');
create trigger userorg_outreach_campaigns_created_by
before insert or update on public.outreach_campaigns
for each row execute function app_private.guard_user_organization('created_by');
create trigger userorg_import_jobs_created_by
before insert or update on public.import_jobs
for each row execute function app_private.guard_user_organization('created_by');

create trigger audit_evidence_bundles after insert or update or delete on public.evidence_bundles
for each row execute function app_private.audit_row_change();
create trigger audit_outreach_campaigns after insert or update or delete on public.outreach_campaigns
for each row execute function app_private.audit_row_change();
create trigger audit_import_jobs after insert or update or delete on public.import_jobs
for each row execute function app_private.audit_row_change();

grant select,insert,update,delete on public.evidence_bundles,public.outreach_campaigns,public.outreach_campaign_members,public.import_jobs to authenticated;
