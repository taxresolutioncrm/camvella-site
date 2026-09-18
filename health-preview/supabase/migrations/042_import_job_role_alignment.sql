-- 042_import_job_role_alignment.sql
-- Bulk client/lead/catalog imports are management-only.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists import_jobs_select on public.import_jobs;
drop policy if exists import_jobs_write on public.import_jobs;

create policy import_jobs_select on public.import_jobs
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

create policy import_jobs_write on public.import_jobs
for all to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);
