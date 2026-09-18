-- 014_settings_templates_preferences.sql
-- Settings and communication/scheduling support used by current UI.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create table public.organization_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  brand_name text,
  timezone text not null default 'America/New_York',
  default_market public.market_type,
  settings jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table public.appointment_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  name text not null,
  market public.market_type,
  duration_minutes integer not null default 30 check(duration_minutes>0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index appointment_types_org_idx on public.appointment_types(organization_id,is_active);

create table public.communication_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  channel public.communication_channel not null,
  name text not null,
  subject text,
  body_text text not null,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index communication_templates_org_idx on public.communication_templates(organization_id,channel,is_active);

create table public.contact_preferences (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  email_allowed boolean not null default true,
  sms_allowed boolean not null default true,
  phone_allowed boolean not null default true,
  fax_allowed boolean not null default true,
  do_not_call boolean not null default false,
  source text,
  note text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(organization_id,client_id)
);

alter table public.organization_settings enable row level security;
alter table public.appointment_types enable row level security;
alter table public.communication_templates enable row level security;
alter table public.contact_preferences enable row level security;

create policy organization_settings_select on public.organization_settings
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy organization_settings_write on public.organization_settings
for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
);

create policy appointment_types_select on public.appointment_types
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy appointment_types_write on public.appointment_types
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

create policy communication_templates_select on public.communication_templates
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy communication_templates_write on public.communication_templates
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

create policy contact_preferences_select on public.contact_preferences
for select to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
);

create policy contact_preferences_write on public.contact_preferences
for all to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
)
with check (
  app_private.is_portal_user_for_client(client_id)
  or exists(select 1 from public.clients c where c.id=client_id and app_private.can_access_office(c.organization_id,c.office_id))
);

create trigger appointment_types_set_updated_at before update on public.appointment_types
for each row execute function public.set_updated_at();
create trigger communication_templates_set_updated_at before update on public.communication_templates
for each row execute function public.set_updated_at();

grant select,insert,update,delete on public.organization_settings, public.appointment_types, public.communication_templates, public.contact_preferences to authenticated;
