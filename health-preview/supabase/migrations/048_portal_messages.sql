-- 048_portal_messages.sql
-- Dedicated client-visible portal messaging, separate from internal agency communication history.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create table public.portal_messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  client_id uuid not null references public.clients(id) on delete cascade,
  direction public.communication_direction not null,
  subject text,
  body_text text not null,
  sender_user_id uuid references auth.users(id) on delete set null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index portal_messages_client_idx
on public.portal_messages(client_id,created_at desc);

create index portal_messages_org_idx
on public.portal_messages(organization_id,created_at desc);

alter table public.portal_messages enable row level security;

create policy portal_messages_select on public.portal_messages
for select to authenticated
using (
  app_private.is_portal_user_for_client(client_id)
  or app_private.can_view_agency_sensitive_client(client_id)
);

create policy portal_messages_insert on public.portal_messages
for insert to authenticated
with check (
  (
    direction='inbound'
    and sender_user_id=(select auth.uid())
    and app_private.is_portal_user_for_client(client_id)
  )
  or (
    direction='outbound'
    and sender_user_id=(select auth.uid())
    and app_private.can_manage_client(client_id)
  )
);

create policy portal_messages_update on public.portal_messages
for update to authenticated
using (
  (
    direction='outbound'
    and app_private.is_portal_user_for_client(client_id)
  )
  or app_private.can_manage_client(client_id)
)
with check (
  app_private.is_portal_user_for_client(client_id)
  or app_private.can_manage_client(client_id)
);

create trigger tenant_portal_messages_office_id
before insert or update on public.portal_messages
for each row execute function app_private.guard_parent_organization('offices','office_id');

create trigger tenant_portal_messages_client_id
before insert or update on public.portal_messages
for each row execute function app_private.guard_parent_organization('clients','client_id');

create trigger userorg_portal_messages_sender_user_id
before insert or update on public.portal_messages
for each row execute function app_private.guard_user_organization('sender_user_id');

create trigger audit_portal_messages
after insert or update or delete on public.portal_messages
for each row execute function app_private.audit_row_change();

grant select,insert,update on public.portal_messages to authenticated;
