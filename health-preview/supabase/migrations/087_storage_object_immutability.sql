-- 087_storage_object_immutability.sql
-- Browser uploads are immutable once written; trusted server paths handle any move/share operation.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists "storage_update_role_scoped" on storage.objects;
drop policy if exists "imports_update_role_scoped" on storage.objects;
