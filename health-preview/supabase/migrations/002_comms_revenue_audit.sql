-- 002_comms_revenue_audit.sql

create table public.communication_threads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  subject text,
  last_channel public.communication_channel,
  last_message_at timestamptz,
  assigned_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);
create index communication_threads_org_idx on public.communication_threads(organization_id);
create index communication_threads_client_idx on public.communication_threads(client_id);
create index communication_threads_last_idx on public.communication_threads(last_message_at desc);

create table public.communications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  thread_id uuid not null references public.communication_threads(id) on delete cascade,
  channel public.communication_channel not null,
  direction public.communication_direction not null,
  client_id uuid references public.clients(id) on delete set null,
  lead_id uuid references public.leads(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  provider text,
  provider_message_id text,
  provider_thread_id text,
  provider_status text,
  from_address text,
  to_address text,
  subject text,
  body_text text,
  body_preview text,
  attachment_count integer not null default 0,
  recording_ref text,
  fax_pages integer,
  voicemail_duration_seconds integer,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  read_at timestamptz
);
create index communications_org_idx on public.communications(organization_id);
create index communications_thread_idx on public.communications(thread_id);
create index communications_provider_idx on public.communications(provider, provider_message_id);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  document_type text not null,
  file_name text not null,
  storage_path text not null,
  mime_type text,
  byte_size bigint,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index documents_org_idx on public.documents(organization_id);
create index documents_client_idx on public.documents(client_id);

create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  consent_type text not null,
  capture_method text not null,
  artifact_document_id uuid references public.documents(id) on delete set null,
  captured_by uuid references auth.users(id) on delete set null,
  captured_at timestamptz not null default now(),
  expires_at timestamptz,
  status text not null default 'valid'
);
create index consent_records_org_idx on public.consent_records(organization_id);
create index consent_records_client_idx on public.consent_records(client_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  assigned_user_id uuid references auth.users(id) on delete set null,
  entity_type text,
  entity_id uuid,
  title text not null,
  priority text not null default 'normal',
  status text not null default 'open',
  due_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index tasks_org_idx on public.tasks(organization_id);
create index tasks_assigned_idx on public.tasks(assigned_user_id,status,due_at);

create table public.carrier_contracts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  carrier_id uuid not null references public.carriers(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  state text not null,
  market public.market_type not null,
  appointment_status text not null default 'pending',
  certification_status text,
  certification_expires_at date,
  external_producer_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index carrier_contracts_org_idx on public.carrier_contracts(organization_id);
create index carrier_contracts_user_idx on public.carrier_contracts(user_id);

create table public.commission_statements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  carrier_id uuid not null references public.carriers(id),
  statement_period_start date,
  statement_period_end date,
  received_at timestamptz not null default now(),
  source_filename text,
  total_amount numeric(14,2) not null default 0,
  row_count integer not null default 0,
  import_status text not null default 'pending',
  created_at timestamptz not null default now()
);
create index commission_statements_org_idx on public.commission_statements(organization_id);

create table public.commission_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  statement_id uuid not null references public.commission_statements(id) on delete cascade,
  external_member_id text,
  external_policy_number text,
  client_id uuid references public.clients(id) on delete set null,
  policy_id uuid references public.policies(id) on delete set null,
  producer_external_id text,
  user_id uuid references auth.users(id) on delete set null,
  commission_type text,
  gross_amount numeric(14,2) not null default 0,
  split_amount numeric(14,2),
  net_amount numeric(14,2) not null default 0,
  effective_date date,
  paid_date date,
  match_status text not null default 'unmatched',
  exception_reason text,
  created_at timestamptz not null default now()
);
create index commission_lines_org_idx on public.commission_lines(organization_id);
create index commission_lines_statement_idx on public.commission_lines(statement_id);
create index commission_lines_policy_idx on public.commission_lines(policy_id);

create table public.commission_exceptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  commission_line_id uuid not null references public.commission_lines(id) on delete cascade,
  reason text not null,
  amount numeric(14,2),
  status text not null default 'open',
  assigned_user_id uuid references auth.users(id) on delete set null,
  resolution_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index commission_exceptions_org_idx on public.commission_exceptions(organization_id);
create index commission_exceptions_status_idx on public.commission_exceptions(status);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_type text not null default 'user',
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_json jsonb,
  after_json jsonb,
  metadata_json jsonb,
  ip_hash text,
  created_at timestamptz not null default now()
);
create index audit_log_org_idx on public.audit_log(organization_id,created_at desc);
create index audit_log_entity_idx on public.audit_log(entity_type,entity_id);
