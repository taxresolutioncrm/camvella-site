-- 069_portal_storage_metadata_alignment.sql
-- Shared portal files must have an explicitly portal-visible document row; portal uploads remain readable immediately.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.portal_can_read_storage_object(object_name text)
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
  portal_allowed boolean;
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

  select exists(
    select 1
    from public.client_portal_accounts p
    where p.user_id=(select auth.uid())
      and p.organization_id=org_id
      and p.client_id=client_id_value
      and p.status='active'
  ) into portal_allowed;

  if not portal_allowed then
    return false;
  end if;

  -- A client can always read its own portal upload path. Agency-shared paths
  -- are exposed only after metadata has explicitly marked the document visible.
  if visibility='portal' then
    return true;
  end if;

  return exists(
    select 1
    from public.documents d
    where d.organization_id=org_id
      and d.client_id=client_id_value
      and d.storage_path=object_name
      and d.portal_visible=true
  );
end;
$$;

revoke all on function app_private.portal_can_read_storage_object(text)
from public, anon;
grant execute on function app_private.portal_can_read_storage_object(text)
to authenticated;
