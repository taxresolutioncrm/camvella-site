-- 006_app_support.sql
-- Product-support tables required by current CRM UI.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.team_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  email text not null,
  role public.member_role not null,
  invited_by uuid references auth.users(id) on delete set null,
  token_hash text not null,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(organization_id,email)
);
create index team_invitations_org_idx on public.team_invitations(organization_id);

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default true,
  in_app_enabled boolean not null default true,
  renewal_alerts boolean not null default true,
  compliance_alerts boolean not null default true,
  commission_alerts boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,user_id)
);

create table public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_type text not null,
  title text not null,
  body text,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index app_notifications_user_idx on public.app_notifications(user_id,read_at,created_at desc);

create table public.automation_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  name text not null,
  trigger_type text not null,
  action_type text not null,
  config jsonb not null default '{}'::jsonb,
  is_enabled boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index automation_rules_org_idx on public.automation_rules(organization_id,is_enabled);

create table public.portal_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  email text not null,
  token_hash text not null,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index portal_invitations_org_idx on public.portal_invitations(organization_id);
create index portal_invitations_client_idx on public.portal_invitations(client_id);

alter table public.user_profiles enable row level security;
alter table public.team_invitations enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.app_notifications enable row level security;
alter table public.automation_rules enable row level security;
alter table public.portal_invitations enable row level security;

create policy user_profiles_select on public.user_profiles
for select to authenticated
using (user_id=(select auth.uid()) or exists (
  select 1 from public.memberships mine
  join public.memberships theirs on theirs.organization_id=mine.organization_id
  where mine.user_id=(select auth.uid()) and mine.is_active=true
    and theirs.user_id=user_profiles.user_id and theirs.is_active=true
));

create policy user_profiles_insert_self on public.user_profiles
for insert to authenticated
with check (user_id=(select auth.uid()));

create policy user_profiles_update_self on public.user_profiles
for update to authenticated
using (user_id=(select auth.uid()))
with check (user_id=(select auth.uid()));

create policy notification_preferences_select on public.notification_preferences
for select to authenticated
using (user_id=(select auth.uid()) and organization_id in (select app_private.current_org_ids()));

create policy notification_preferences_write on public.notification_preferences
for all to authenticated
using (user_id=(select auth.uid()) and organization_id in (select app_private.current_org_ids()))
with check (user_id=(select auth.uid()) and organization_id in (select app_private.current_org_ids()));

create policy app_notifications_select on public.app_notifications
for select to authenticated
using (user_id=(select auth.uid()) and organization_id in (select app_private.current_org_ids()));

create policy app_notifications_update on public.app_notifications
for update to authenticated
using (user_id=(select auth.uid()) and organization_id in (select app_private.current_org_ids()))
with check (user_id=(select auth.uid()) and organization_id in (select app_private.current_org_ids()));

create policy team_invitations_select on public.team_invitations
for select to authenticated
using (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[]));

create policy team_invitations_write on public.team_invitations
for all to authenticated
using (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[]))
with check (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[]));

create policy automation_rules_select on public.automation_rules
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy automation_rules_write on public.automation_rules
for all to authenticated
using (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[]))
with check (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[]));

create policy portal_invitations_select on public.portal_invitations
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy portal_invitations_write on public.portal_invitations
for all to authenticated
using (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[]))
with check (organization_id in (select app_private.current_org_ids()) and app_private.has_org_role(organization_id,array['agency_admin','manager','agent']::public.member_role[]));

create trigger user_profiles_set_updated_at before update on public.user_profiles
for each row execute function public.set_updated_at();
create trigger notification_preferences_set_updated_at before update on public.notification_preferences
for each row execute function public.set_updated_at();
create trigger automation_rules_set_updated_at before update on public.automation_rules
for each row execute function public.set_updated_at();