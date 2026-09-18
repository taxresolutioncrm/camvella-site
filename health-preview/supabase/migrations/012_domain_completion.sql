-- 012_domain_completion.sql
-- Completes data domains already represented in the CRM UI.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create table public.client_providers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  provider_name text not null,
  specialty text,
  provider_identifier text,
  preference_level text not null default 'preferred',
  network_status text,
  created_at timestamptz not null default now()
);
create index client_providers_client_idx on public.client_providers(client_id);

create table public.client_prescriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  medication_name text not null,
  dosage text,
  frequency text,
  external_drug_id text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index client_prescriptions_client_idx on public.client_prescriptions(client_id);

create table public.client_pharmacies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  pharmacy_name text not null,
  phone text,
  address jsonb not null default '{}'::jsonb,
  external_pharmacy_id text,
  is_preferred boolean not null default false,
  created_at timestamptz not null default now()
);
create index client_pharmacies_client_idx on public.client_pharmacies(client_id);

create table public.plan_comparisons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid not null references public.clients(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  market public.market_type not null,
  input_snapshot jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index plan_comparisons_client_idx on public.plan_comparisons(client_id,created_at desc);

create table public.plan_comparison_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  comparison_id uuid not null references public.plan_comparisons(id) on delete cascade,
  carrier_product_id uuid references public.carrier_products(id) on delete set null,
  external_plan_id text,
  plan_name text not null,
  premium_amount numeric(12,2),
  deductible_amount numeric(12,2),
  provider_match_count integer,
  provider_total_count integer,
  drug_match_count integer,
  drug_total_count integer,
  estimated_fit text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index plan_comparison_items_comparison_idx on public.plan_comparison_items(comparison_id);

create table public.agent_licenses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  state text not null,
  license_number text not null,
  license_type text,
  status text not null default 'active',
  issued_at date,
  expires_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,user_id,state,license_number)
);
create index agent_licenses_org_user_idx on public.agent_licenses(organization_id,user_id);

create table public.client_portal_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  unique(organization_id,client_id,user_id)
);
create index client_portal_accounts_user_idx on public.client_portal_accounts(user_id,status);

create table public.communication_attachments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  communication_id uuid not null references public.communications(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(communication_id,document_id)
);

alter table public.client_providers enable row level security;
alter table public.client_prescriptions enable row level security;
alter table public.client_pharmacies enable row level security;
alter table public.plan_comparisons enable row level security;
alter table public.plan_comparison_items enable row level security;
alter table public.agent_licenses enable row level security;
alter table public.client_portal_accounts enable row level security;
alter table public.communication_attachments enable row level security;

create or replace function app_private.is_portal_user_for_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.client_portal_accounts p
    where p.client_id=target_client
      and p.user_id=(select auth.uid())
      and p.status='active'
  )
$$;
revoke all on function app_private.is_portal_user_for_client(uuid) from public, anon;
grant execute on function app_private.is_portal_user_for_client(uuid) to authenticated;

-- Agency users and the client themselves can read preference/health-plan inputs.
create policy client_providers_select on public.client_providers for select to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
);
create policy client_providers_write on public.client_providers for all to authenticated
using (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)))
with check (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)));

create policy client_prescriptions_select on public.client_prescriptions for select to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
);
create policy client_prescriptions_write on public.client_prescriptions for all to authenticated
using (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)))
with check (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)));

create policy client_pharmacies_select on public.client_pharmacies for select to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
);
create policy client_pharmacies_write on public.client_pharmacies for all to authenticated
using (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)))
with check (exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id)));

create policy plan_comparisons_select on public.plan_comparisons for select to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or app_private.can_access_office(organization_id,office_id)
);
create policy plan_comparisons_write on public.plan_comparisons for all to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));

create policy plan_comparison_items_select on public.plan_comparison_items for select to authenticated
using (exists(select 1 from public.plan_comparisons pc where pc.id=comparison_id and (
  app_private.is_portal_user_for_client(pc.client_id)
  or app_private.can_access_office(pc.organization_id,pc.office_id)
)));
create policy plan_comparison_items_write on public.plan_comparison_items for all to authenticated
using (exists(select 1 from public.plan_comparisons pc where pc.id=comparison_id and app_private.can_access_office(pc.organization_id,pc.office_id)))
with check (exists(select 1 from public.plan_comparisons pc where pc.id=comparison_id and app_private.can_access_office(pc.organization_id,pc.office_id)));

create policy agent_licenses_select on public.agent_licenses for select to authenticated
using (organization_id in (select app_private.current_org_ids()));
create policy agent_licenses_write on public.agent_licenses for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
);

create policy client_portal_accounts_select on public.client_portal_accounts for select to authenticated
using (
  user_id=(select auth.uid())
  or organization_id in (select app_private.current_org_ids())
);

create policy communication_attachments_select on public.communication_attachments for select to authenticated
using (exists(
  select 1 from public.communications c
  where c.id=communication_id
    and app_private.can_access_office(c.organization_id,c.office_id)
));
create policy communication_attachments_write on public.communication_attachments for all to authenticated
using (exists(
  select 1 from public.communications c
  where c.id=communication_id
    and app_private.can_access_office(c.organization_id,c.office_id)
))
with check (exists(
  select 1 from public.communications c
  where c.id=communication_id
    and app_private.can_access_office(c.organization_id,c.office_id)
));

-- Extend portal visibility to the client's own core records.
drop policy if exists clients_select on public.clients;
create policy clients_select on public.clients for select to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  or app_private.is_portal_user_for_client(id)
);

drop policy if exists policies_select on public.policies;
create policy policies_select on public.policies for select to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  or app_private.is_portal_user_for_client(client_id)
);

drop policy if exists documents_all on public.documents;
create policy documents_select on public.documents for select to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  or (client_id is not null and app_private.is_portal_user_for_client(client_id))
);
create policy documents_insert on public.documents for insert to authenticated
with check (
  app_private.can_access_office(organization_id,office_id)
  or (client_id is not null and app_private.is_portal_user_for_client(client_id))
);
create policy documents_update on public.documents for update to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));
create policy documents_delete on public.documents for delete to authenticated
using (app_private.can_access_office(organization_id,office_id));

drop policy if exists service_requests_all on public.service_requests;
create policy service_requests_select on public.service_requests for select to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  or app_private.is_portal_user_for_client(client_id)
);
create policy service_requests_insert on public.service_requests for insert to authenticated
with check (
  app_private.can_access_office(organization_id,office_id)
  or app_private.is_portal_user_for_client(client_id)
);
create policy service_requests_update on public.service_requests for update to authenticated
using (app_private.can_access_office(organization_id,office_id))
with check (app_private.can_access_office(organization_id,office_id));
create policy service_requests_delete on public.service_requests for delete to authenticated
using (app_private.can_access_office(organization_id,office_id));

create trigger agent_licenses_set_updated_at before update on public.agent_licenses
for each row execute function public.set_updated_at();

grant select,insert,update,delete on public.client_providers, public.client_prescriptions, public.client_pharmacies, public.plan_comparisons, public.plan_comparison_items, public.agent_licenses, public.communication_attachments to authenticated;
grant select on public.client_portal_accounts to authenticated;
