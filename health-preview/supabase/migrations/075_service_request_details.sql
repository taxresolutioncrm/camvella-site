-- 075_service_request_details.sql
-- Stores request details on the request itself and makes portal request creation atomic.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.service_requests
add column details text;

drop function if exists public.create_my_portal_service_request(text,text);

create or replace function public.create_my_portal_service_request(
  p_request_type text,
  p_priority text default 'normal',
  p_details text default null
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
  normalized_details text:=nullif(left(trim(coalesce(p_details,'')),4000),'');
  active_assignee uuid;
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
  order by p.created_at
  limit 1;

  if account.id is null then
    raise exception 'active portal account required';
  end if;

  select * into c
  from public.clients
  where id=account.client_id
    and organization_id=account.organization_id;

  if c.id is null then
    raise exception 'portal client not found';
  end if;

  select m.user_id into active_assignee
  from public.memberships m
  where m.organization_id=c.organization_id
    and m.user_id=c.assigned_user_id
    and m.is_active=true
  limit 1;

  insert into public.service_requests(
    organization_id,
    office_id,
    client_id,
    request_type,
    details,
    source,
    priority,
    status,
    assigned_user_id
  ) values (
    c.organization_id,
    c.office_id,
    c.id,
    trim(p_request_type),
    normalized_details,
    'client_portal',
    normalized_priority,
    'open',
    active_assignee
  )
  returning id into request_id;

  return request_id;
end;
$$;

revoke all on function public.create_my_portal_service_request(text,text,text)
from public, anon;
grant execute on function public.create_my_portal_service_request(text,text,text)
to authenticated;
