-- 047_portal_data_boundary.sql
-- Separates internal agency records from explicitly client-visible portal data.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.can_view_internal_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.clients c
    join public.memberships m on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        m.role in ('agency_admin','manager','compliance','revenue')
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (c.office_id is null or m.office_id=c.office_id)
        )
      )
  )
$$;

revoke all on function app_private.can_view_internal_client(uuid)
from public, anon;
grant execute on function app_private.can_view_internal_client(uuid)
to authenticated;

alter table public.documents
add column portal_visible boolean not null default false;

alter table public.policy_events
add column portal_visible boolean not null default false;

-- Renewal work queues contain internal risk/outreach fields and are agency-only.
drop policy if exists renewals_select on public.renewals;
create policy renewals_select on public.renewals
for select to authenticated
using (app_private.can_view_internal_client(client_id));

-- Policy events are internal unless explicitly shared.
drop policy if exists policy_events_select on public.policy_events;
create policy policy_events_select on public.policy_events
for select to authenticated
using (
  app_private.can_view_internal_client(
    (select p.client_id from public.policies p where p.id=policy_id)
  )
  or (
    portal_visible=true
    and app_private.is_portal_user_for_client(
      (select p.client_id from public.policies p where p.id=policy_id)
    )
  )
);

-- Documents are internal unless explicitly shared, while portal-uploaded documents
-- can still be inserted for the portal user's own client.
drop policy if exists documents_select on public.documents;
create policy documents_select on public.documents
for select to authenticated
using (
  (client_id is not null and app_private.can_view_agency_sensitive_client(client_id))
  or (
    client_id is not null
    and portal_visible=true
    and app_private.is_portal_user_for_client(client_id)
  )
  or (
    client_id is null
    and app_private.has_org_role(
      organization_id,
      array['agency_admin','manager','compliance']::public.member_role[]
    )
  )
);

drop policy if exists documents_insert on public.documents;
create policy documents_insert on public.documents
for insert to authenticated
with check (
  (
    client_id is not null
    and app_private.is_portal_user_for_client(client_id)
    and portal_visible=true
  )
  or (
    client_id is not null
    and app_private.can_manage_client(client_id)
  )
  or app_private.has_org_role(
    organization_id,
    array['compliance']::public.member_role[]
  )
);

-- Portal users cannot mutate document metadata after creation.
drop policy if exists documents_update on public.documents;
create policy documents_update on public.documents
for update to authenticated
using (
  (client_id is not null and app_private.can_manage_client(client_id))
  or app_private.has_org_role(
    organization_id,
    array['compliance']::public.member_role[]
  )
)
with check (
  (client_id is not null and app_private.can_manage_client(client_id))
  or app_private.has_org_role(
    organization_id,
    array['compliance']::public.member_role[]
  )
);

-- Contact preferences do not belong in revenue operations.
drop policy if exists contact_preferences_select on public.contact_preferences;
drop policy if exists contact_preferences_write on public.contact_preferences;

create policy contact_preferences_select on public.contact_preferences
for select to authenticated
using (
  (
    client_id is not null
    and (
      app_private.is_portal_user_for_client(client_id)
      or app_private.can_view_agency_sensitive_client(client_id)
    )
  )
  or (
    lead_id is not null
    and exists(
      select 1
      from public.leads l
      where l.id=lead_id
        and (
          app_private.has_org_role(
            l.organization_id,
            array['agency_admin','manager']::public.member_role[]
          )
          or (
            l.assigned_user_id=(select auth.uid())
            and app_private.has_org_role(
              l.organization_id,
              array['agent']::public.member_role[]
            )
          )
        )
    )
  )
);

create policy contact_preferences_write on public.contact_preferences
for all to authenticated
using (
  (
    client_id is not null
    and (
      app_private.is_portal_user_for_client(client_id)
      or app_private.can_manage_client(client_id)
    )
  )
  or (
    lead_id is not null
    and exists(
      select 1
      from public.leads l
      where l.id=lead_id
        and (
          app_private.has_org_role(
            l.organization_id,
            array['agency_admin','manager']::public.member_role[]
          )
          or (
            l.assigned_user_id=(select auth.uid())
            and app_private.has_org_role(
              l.organization_id,
              array['agent']::public.member_role[]
            )
          )
        )
    )
  )
)
with check (
  (
    client_id is not null
    and (
      app_private.is_portal_user_for_client(client_id)
      or app_private.can_manage_client(client_id)
    )
  )
  or (
    lead_id is not null
    and exists(
      select 1
      from public.leads l
      where l.id=lead_id
        and (
          app_private.has_org_role(
            l.organization_id,
            array['agency_admin','manager']::public.member_role[]
          )
          or (
            l.assigned_user_id=(select auth.uid())
            and app_private.has_org_role(
              l.organization_id,
              array['agent']::public.member_role[]
            )
          )
        )
    )
  )
);

-- Client-document path segment 4 declares visibility:
-- agency = agency-only, portal = client-uploaded, shared = explicitly client-visible.
create or replace function app_private.portal_can_access_storage_object(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
  client_id_value uuid;
  visibility text;
begin
  begin
    org_id:=split_part(object_name,'/',1)::uuid;
    client_id_value:=split_part(object_name,'/',3)::uuid;
    visibility:=split_part(object_name,'/',4);
  exception when others then
    return false;
  end;

  if visibility not in ('portal','shared') then
    return false;
  end if;

  return exists(
    select 1
    from public.client_portal_accounts p
    where p.user_id=(select auth.uid())
      and p.organization_id=org_id
      and p.client_id=client_id_value
      and p.status='active'
  );
end;
$$;

revoke all on function app_private.portal_can_access_storage_object(text)
from public, anon;
grant execute on function app_private.portal_can_access_storage_object(text)
to authenticated;
