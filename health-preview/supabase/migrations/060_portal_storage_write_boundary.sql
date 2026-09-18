-- 060_portal_storage_write_boundary.sql
-- Portal users may read portal/shared files but may upload only into their own portal path.
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

create or replace function app_private.portal_can_upload_storage_object(object_name text)
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

  if visibility <> 'portal' then
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

revoke all on function app_private.portal_can_read_storage_object(text) from public, anon;
revoke all on function app_private.portal_can_upload_storage_object(text) from public, anon;
grant execute on function app_private.portal_can_read_storage_object(text) to authenticated;
grant execute on function app_private.portal_can_upload_storage_object(text) to authenticated;

drop policy if exists "storage_select_portal_client_documents" on storage.objects;
drop policy if exists "storage_insert_portal_client_documents" on storage.objects;

create policy "storage_select_portal_client_documents"
on storage.objects
for select to authenticated
using (
  bucket_id='client-documents'
  and app_private.portal_can_read_storage_object(name)
);

create policy "storage_insert_portal_client_documents"
on storage.objects
for insert to authenticated
with check (
  bucket_id='client-documents'
  and app_private.portal_can_upload_storage_object(name)
);

-- Keep private buckets constrained even before provider-specific limits are known.
update storage.buckets
set file_size_limit=26214400
where id in ('client-documents','enrollment-evidence','communications','commission-statements','imports')
  and (file_size_limit is null or file_size_limit>26214400);
