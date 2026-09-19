-- 079_portal_request_projection.sql
-- Returns client-safe request details without exposing internal assignment/SLA fields.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop function if exists public.list_my_portal_service_requests();

create or replace function public.list_my_portal_service_requests()
returns table(
  id uuid,
  request_type text,
  details text,
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
    sr.details,
    sr.priority,
    sr.status,
    sr.created_at,
    sr.resolved_at
  from public.client_portal_accounts p
  join public.service_requests sr
    on sr.client_id=p.client_id
   and sr.organization_id=p.organization_id
  where p.user_id=(select auth.uid())
    and p.status='active'
  order by sr.created_at desc
$$;

revoke all on function public.list_my_portal_service_requests()
from public, anon;
grant execute on function public.list_my_portal_service_requests()
to authenticated;
