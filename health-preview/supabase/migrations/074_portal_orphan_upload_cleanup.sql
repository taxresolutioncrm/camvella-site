-- 074_portal_orphan_upload_cleanup.sql
-- Lets a portal user clean up only an uncommitted upload if document metadata insertion fails.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.portal_can_cleanup_storage_object(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
  office_segment text;
  client_id_value uuid;
  visibility text;
  expected_office text;
begin
  begin
    org_id:=split_part(object_name,'/',1)::uuid;
    office_segment:=split_part(object_name,'/',2);
    client_id_value:=split_part(object_name,'/',3)::uuid;
    visibility:=split_part(object_name,'/',4);
  exception when others then
    return false;
  end;

  if visibility<>'portal' then
    return false;
  end if;

  select coalesce(c.office_id::text,'shared')
  into expected_office
  from public.clients c
  where c.id=client_id_value
    and c.organization_id=org_id;

  if expected_office is null or office_segment<>expected_office then
    return false;
  end if;

  if not exists(
    select 1
    from public.client_portal_accounts p
    where p.user_id=(select auth.uid())
      and p.organization_id=org_id
      and p.client_id=client_id_value
      and p.status='active'
  ) then
    return false;
  end if;

  -- Once metadata exists, the object is committed and the portal browser
  -- cannot delete it directly.
  return not exists(
    select 1
    from public.documents d
    where d.organization_id=org_id
      and d.client_id=client_id_value
      and d.storage_path=object_name
  );
end;
$$;

revoke all on function app_private.portal_can_cleanup_storage_object(text)
from public, anon;
grant execute on function app_private.portal_can_cleanup_storage_object(text)
to authenticated;

drop policy if exists "storage_delete_portal_orphan_upload" on storage.objects;
create policy "storage_delete_portal_orphan_upload"
on storage.objects
for delete to authenticated
using (
  bucket_id='client-documents'
  and app_private.portal_can_cleanup_storage_object(name)
);
