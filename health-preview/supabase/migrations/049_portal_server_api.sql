-- 049_portal_server_api.sql
-- Narrow client-portal RPC surface for profile, requests, and secure messages.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function public.get_my_portal_profile()
returns table(
  id uuid,
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
    c.id,c.organization_id,c.office_id,c.first_name,c.last_name,
    c.email,c.phone,c.market,c.portal_status
  from public.client_portal_accounts p
  join public.clients c on c.id=p.client_id and c.organization_id=p.organization_id
  where p.user_id=(select auth.uid())
    and p.status='active'
  order by p.created_at desc
  limit 1
$$;

revoke all on function public.get_my_portal_profile() from public, anon;
grant execute on function public.get_my_portal_profile() to authenticated;

create or replace function public.list_my_portal_service_requests()
returns table(
  id uuid,
  request_type text,
  priority text,
  status text,
  source text,
  created_at timestamptz,
  resolved_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    sr.id,sr.request_type,sr.priority,sr.status,sr.source,sr.created_at,sr.resolved_at
  from public.client_portal_accounts p
  join public.service_requests sr
    on sr.client_id=p.client_id
   and sr.organization_id=p.organization_id
  where p.user_id=(select auth.uid())
    and p.status='active'
  order by sr.created_at desc
$$;

revoke all on function public.list_my_portal_service_requests() from public, anon;
grant execute on function public.list_my_portal_service_requests() to authenticated;

create or replace function public.create_my_portal_service_request(
  p_request_type text,
  p_priority text default 'normal'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  p public.client_portal_accounts%rowtype;
  c public.clients%rowtype;
  request_id uuid;
  normalized_priority text:=lower(trim(coalesce(p_priority,'normal')));
begin
  select * into p
  from public.client_portal_accounts
  where user_id=(select auth.uid())
    and status='active'
  order by created_at desc
  limit 1;

  if p.id is null then
    raise exception 'active portal account required';
  end if;

  select * into c
  from public.clients
  where id=p.client_id
    and organization_id=p.organization_id;

  if c.id is null then
    raise exception 'portal client not found';
  end if;

  if length(trim(coalesce(p_request_type,'')))<2 then
    raise exception 'request type is required';
  end if;

  if normalized_priority not in ('normal','high','urgent') then
    raise exception 'invalid priority';
  end if;

  insert into public.service_requests(
    organization_id,office_id,client_id,request_type,source,priority,status
  ) values (
    c.organization_id,c.office_id,c.id,trim(p_request_type),'portal',normalized_priority,'open'
  )
  returning id into request_id;

  return jsonb_build_object('request_id',request_id);
end;
$$;

revoke all on function public.create_my_portal_service_request(text,text) from public, anon;
grant execute on function public.create_my_portal_service_request(text,text) to authenticated;

create or replace function public.list_my_portal_messages()
returns table(
  id uuid,
  direction public.communication_direction,
  subject text,
  body_text text,
  created_at timestamptz,
  read_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    m.id,m.direction,m.subject,m.body_text,m.created_at,m.read_at
  from public.client_portal_accounts p
  join public.communications m
    on m.client_id=p.client_id
   and m.organization_id=p.organization_id
   and m.channel='portal'
  where p.user_id=(select auth.uid())
    and p.status='active'
  order by m.created_at asc
$$;

revoke all on function public.list_my_portal_messages() from public, anon;
grant execute on function public.list_my_portal_messages() to authenticated;

create or replace function public.mark_my_portal_messages_read(
  p_message_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  updated_count integer;
begin
  update public.communications m
  set read_at=coalesce(m.read_at,now())
  where m.id=any(coalesce(p_message_ids,'{}'::uuid[]))
    and m.channel='portal'
    and m.direction='outbound'
    and exists(
      select 1
      from public.client_portal_accounts p
      where p.user_id=(select auth.uid())
        and p.status='active'
        and p.client_id=m.client_id
        and p.organization_id=m.organization_id
    );

  get diagnostics updated_count=row_count;
  return updated_count;
end;
$$;

revoke all on function public.mark_my_portal_messages_read(uuid[]) from public, anon;
grant execute on function public.mark_my_portal_messages_read(uuid[]) to authenticated;
