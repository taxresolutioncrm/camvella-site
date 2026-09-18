-- 050_portal_least_privilege.sql
-- Removes portal users from broad client/sensitive-table reads and exposes only portal-safe RPCs.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.can_view_sensitive_client(target_client uuid)
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
        m.role in ('agency_admin','manager','compliance')
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (c.office_id is null or m.office_id=c.office_id)
        )
      )
  )
$$;

revoke all on function app_private.can_view_sensitive_client(uuid)
from public, anon;
grant execute on function app_private.can_view_sensitive_client(uuid)
to authenticated;

drop policy if exists clients_select on public.clients;
create policy clients_select on public.clients
for select to authenticated
using (app_private.can_view_internal_client(id));

drop policy if exists service_requests_select on public.service_requests;
drop policy if exists service_requests_insert on public.service_requests;

create policy service_requests_select on public.service_requests
for select to authenticated
using (app_private.can_view_internal_client(client_id));

create policy service_requests_insert on public.service_requests
for insert to authenticated
with check (app_private.can_manage_client(client_id));

create or replace function public.get_my_portal_profile()
returns table(
  client_id uuid,
  organization_id uuid,
  office_id uuid,
  first_name text,
  last_name text,
  email text,
  phone text,
  market public.market_type,
  portal_status text
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    c.id,
    c.organization_id,
    c.office_id,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.market,
    c.portal_status
  from public.client_portal_accounts p
  join public.clients c on c.id=p.client_id
  where p.user_id=(select auth.uid())
    and p.status='active'
  limit 1
$$;

revoke all on function public.get_my_portal_profile()
from public, anon;
grant execute on function public.get_my_portal_profile()
to authenticated;

create or replace function public.list_my_portal_service_requests()
returns table(
  id uuid,
  request_type text,
  priority text,
  status text,
  created_at timestamptz,
  resolved_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    sr.id,
    sr.request_type,
    sr.priority,
    sr.status,
    sr.created_at,
    sr.resolved_at
  from public.client_portal_accounts p
  join public.service_requests sr on sr.client_id=p.client_id
  where p.user_id=(select auth.uid())
    and p.status='active'
  order by sr.created_at desc
$$;

revoke all on function public.list_my_portal_service_requests()
from public, anon;
grant execute on function public.list_my_portal_service_requests()
to authenticated;

create or replace function public.create_my_portal_service_request(
  p_request_type text,
  p_priority text default 'normal'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  account public.client_portal_accounts%rowtype;
  c public.clients%rowtype;
  request_id uuid;
  normalized_priority text:=lower(trim(coalesce(p_priority,'normal')));
begin
  if length(trim(coalesce(p_request_type,'')))<2 then
    raise exception 'request type is required';
  end if;

  if normalized_priority not in ('normal','high','urgent') then
    raise exception 'invalid priority';
  end if;

  select * into account
  from public.client_portal_accounts p
  where p.user_id=(select auth.uid())
    and p.status='active'
  limit 1;

  if account.id is null then
    raise exception 'active portal account required';
  end if;

  select * into c
  from public.clients
  where id=account.client_id;

  insert into public.service_requests(
    organization_id,
    office_id,
    client_id,
    request_type,
    source,
    priority,
    status,
    assigned_user_id
  ) values (
    c.organization_id,
    c.office_id,
    c.id,
    trim(p_request_type),
    'client_portal',
    normalized_priority,
    'open',
    c.assigned_user_id
  )
  returning id into request_id;

  return request_id;
end;
$$;

revoke all on function public.create_my_portal_service_request(text,text)
from public, anon;
grant execute on function public.create_my_portal_service_request(text,text)
to authenticated;
