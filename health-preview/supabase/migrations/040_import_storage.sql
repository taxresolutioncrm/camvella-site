-- 040_import_storage.sql
-- Private import staging bucket with role-scoped access.
-- DO NOT APPLY until the dedicated Supabase project is selected.

insert into storage.buckets(id,name,public)
values('imports','imports',false)
on conflict(id) do nothing;

create or replace function app_private.can_access_import_object(
  p_name text,
  p_write boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
begin
  begin
    org_id:=split_part(p_name,'/',1)::uuid;
  exception when others then
    return false;
  end;

  if p_write then
    return app_private.has_org_role(org_id,array['agency_admin','manager','revenue']::public.member_role[]);
  end if;

  return app_private.has_org_role(org_id,array['agency_admin','manager','revenue']::public.member_role[]);
end;
$$;

revoke all on function app_private.can_access_import_object(text,boolean) from public, anon;
grant execute on function app_private.can_access_import_object(text,boolean) to authenticated;

create policy "imports_select_role_scoped"
on storage.objects
for select to authenticated
using (
  bucket_id='imports'
  and app_private.can_access_import_object(name,false)
);

create policy "imports_insert_role_scoped"
on storage.objects
for insert to authenticated
with check (
  bucket_id='imports'
  and app_private.can_access_import_object(name,true)
);

create policy "imports_update_role_scoped"
on storage.objects
for update to authenticated
using (
  bucket_id='imports'
  and app_private.can_access_import_object(name,true)
)
with check (
  bucket_id='imports'
  and app_private.can_access_import_object(name,true)
);

create policy "imports_delete_role_scoped"
on storage.objects
for delete to authenticated
using (
  bucket_id='imports'
  and app_private.can_access_import_object(name,true)
);
