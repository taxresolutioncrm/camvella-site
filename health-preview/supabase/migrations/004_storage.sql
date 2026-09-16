-- 004_storage.sql
-- Bucket creation + RLS draft. DO NOT APPLY until dedicated project is selected.
-- Object operations must use the Storage API; storage schema metadata is not edited directly.

insert into storage.buckets (id,name,public)
values
  ('client-documents','client-documents',false),
  ('enrollment-evidence','enrollment-evidence',false),
  ('communications','communications',false),
  ('commission-statements','commission-statements',false)
on conflict (id) do nothing;

-- Required object path convention:
-- <organization_id>/<office_id-or-shared>/<entity_id>/<filename>

create policy "storage_select_org"
on storage.objects
for select to authenticated
using (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and split_part(name,'/',1)::uuid in (select app_private.current_org_ids())
);

create policy "storage_insert_org"
on storage.objects
for insert to authenticated
with check (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and split_part(name,'/',1)::uuid in (select app_private.current_org_ids())
);

create policy "storage_update_org"
on storage.objects
for update to authenticated
using (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and split_part(name,'/',1)::uuid in (select app_private.current_org_ids())
)
with check (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and split_part(name,'/',1)::uuid in (select app_private.current_org_ids())
);

create policy "storage_delete_org"
on storage.objects
for delete to authenticated
using (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and split_part(name,'/',1)::uuid in (select app_private.current_org_ids())
);
