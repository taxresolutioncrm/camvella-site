-- 043_commission_statement_storage.sql
-- Links uploaded commission statement files to their statement records.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.commission_statements
add column storage_path text;

create unique index commission_statements_storage_path_uq
on public.commission_statements(organization_id,storage_path)
where storage_path is not null;
