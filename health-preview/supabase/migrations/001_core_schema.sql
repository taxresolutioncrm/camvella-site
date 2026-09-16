-- 001_core_schema.sql
-- Migration-ready draft. DO NOT APPLY until the dedicated Supabase project is selected.

create extension if not exists pgcrypto;

create type public.market_type as enum ('aca','medicare');
create type public.member_role as enum ('agency_admin','manager','agent','compliance','revenue');
create type public.enrollment_status as enum ('draft','needs_review','ready','submitted','pending','approved','active','denied','cancelled');
create type public.communication_channel as enum ('email','phone','sms','fax','voicemail','portal');
create type public.communication_direction as enum ('inbound','outbound');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table public.offices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  timezone text not null default 'America/New_York',
  phone text,
  email text,
  fax text,
  created_at timestamptz not null default now()
);
create index offices_org_idx on public.offices(organization_id);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(organization_id,user_id)
);
create index memberships_user_idx on public.memberships(user_id);
create index memberships_org_idx on public.memberships(organization_id);

create table public.leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  assigned_user_id uuid references auth.users(id) on delete set null,
  first_name text not null,
  last_name text not null,
  email text,
  phone text,
  market public.market_type not null,
  source text,
  stage text not null default 'new',
  score integer check (score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index leads_org_idx on public.leads(organization_id);
create index leads_office_idx on public.leads(office_id);
create index leads_assigned_idx on public.leads(assigned_user_id);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  assigned_user_id uuid references auth.users(id) on delete set null,
  first_name text not null,
  last_name text not null,
  dob date,
  email text,
  phone text,
  market public.market_type not null,
  portal_status text not null default 'not_invited',
  renewal_risk text not null default 'low',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index clients_org_idx on public.clients(organization_id);
create index clients_office_idx on public.clients(office_id);
create index clients_assigned_idx on public.clients(assigned_user_id);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  household_size integer not null check (household_size > 0),
  annual_income numeric(12,2),
  state text,
  county text,
  subsidy_estimate numeric(12,2),
  eligibility_status text,
  created_at timestamptz not null default now()
);
create index households_org_idx on public.households(organization_id);
create index households_client_idx on public.households(client_id);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  dob date,
  relationship text,
  tobacco_use boolean not null default false,
  applicant_status text,
  created_at timestamptz not null default now()
);
create index household_members_org_idx on public.household_members(organization_id);
create index household_members_household_idx on public.household_members(household_id);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  assigned_user_id uuid references auth.users(id) on delete set null,
  appointment_type text not null,
  starts_at timestamptz not null,
  duration_minutes integer not null default 30 check (duration_minutes > 0),
  status text not null default 'scheduled',
  outcome text,
  created_at timestamptz not null default now()
);
create index appointments_org_idx on public.appointments(organization_id);
create index appointments_starts_idx on public.appointments(starts_at);

create table public.carriers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  market public.market_type,
  status text not null default 'active',
  created_at timestamptz not null default now()
);
create index carriers_org_idx on public.carriers(organization_id);

create table public.carrier_products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  carrier_id uuid not null references public.carriers(id) on delete cascade,
  market public.market_type not null,
  product_name text not null,
  product_type text,
  state text,
  plan_year integer,
  external_product_id text,
  status text not null default 'active',
  created_at timestamptz not null default now()
);
create index carrier_products_org_idx on public.carrier_products(organization_id);
create index carrier_products_carrier_idx on public.carrier_products(carrier_id);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid not null references public.clients(id) on delete cascade,
  assigned_user_id uuid references auth.users(id) on delete set null,
  market public.market_type not null,
  enrollment_type text,
  lifecycle_status public.enrollment_status not null default 'draft',
  eligibility_status text,
  carrier_id uuid references public.carriers(id) on delete set null,
  carrier_product_id uuid references public.carrier_products(id) on delete set null,
  submitted_at timestamptz,
  effective_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index enrollments_org_idx on public.enrollments(organization_id);
create index enrollments_client_idx on public.enrollments(client_id);
create index enrollments_status_idx on public.enrollments(lifecycle_status);

create table public.enrollment_evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  evidence_type text not null,
  status text not null default 'pending',
  storage_path text,
  external_ref text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index enrollment_evidence_org_idx on public.enrollment_evidence(organization_id);
create index enrollment_evidence_enrollment_idx on public.enrollment_evidence(enrollment_id);

create table public.policies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid not null references public.clients(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  carrier_id uuid not null references public.carriers(id),
  carrier_product_id uuid references public.carrier_products(id),
  policy_number text,
  status text not null default 'active',
  effective_date date not null,
  termination_date date,
  renewal_date date,
  premium_amount numeric(12,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index policies_org_idx on public.policies(organization_id);
create index policies_client_idx on public.policies(client_id);

create table public.policy_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  policy_id uuid not null references public.policies(id) on delete cascade,
  event_type text not null,
  summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index policy_events_org_idx on public.policy_events(organization_id);
create index policy_events_policy_idx on public.policy_events(policy_id);

create table public.service_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid not null references public.clients(id) on delete cascade,
  policy_id uuid references public.policies(id) on delete set null,
  request_type text not null,
  source text not null,
  priority text not null default 'normal',
  status text not null default 'open',
  assigned_user_id uuid references auth.users(id) on delete set null,
  sla_due_at timestamptz,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index service_requests_org_idx on public.service_requests(organization_id);
create index service_requests_client_idx on public.service_requests(client_id);

create table public.renewals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid not null references public.clients(id) on delete cascade,
  policy_id uuid not null references public.policies(id) on delete cascade,
  market public.market_type not null,
  review_window_start date,
  review_window_end date,
  risk_level text not null default 'low',
  outreach_status text not null default 'not_started',
  appointment_id uuid references public.appointments(id) on delete set null,
  outcome text,
  created_at timestamptz not null default now()
);
create index renewals_org_idx on public.renewals(organization_id);
create index renewals_window_idx on public.renewals(review_window_start, review_window_end);
