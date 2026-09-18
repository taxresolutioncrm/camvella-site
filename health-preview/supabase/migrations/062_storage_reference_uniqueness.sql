-- 062_storage_reference_uniqueness.sql
-- Prevents duplicate metadata records from pointing at the same private object.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create unique index documents_storage_path_uq
on public.documents(storage_path);

create unique index enrollment_evidence_storage_path_uq
on public.enrollment_evidence(storage_path)
where storage_path is not null;

create unique index import_jobs_storage_path_uq
on public.import_jobs(organization_id,storage_path);
