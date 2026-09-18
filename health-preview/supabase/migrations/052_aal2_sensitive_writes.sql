-- 052_aal2_sensitive_writes.sql
-- Requires AAL2 for sensitive administrative and revenue mutations.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.has_aal2()
returns boolean
language sql
stable
security invoker
set search_path = public, auth
as $$
  select coalesce((auth.jwt()->>'aal')='aal2',false)
$$;

revoke all on function app_private.has_aal2() from public, anon;
grant execute on function app_private.has_aal2() to authenticated;

drop policy if exists memberships_update on public.memberships;
create policy memberships_update on public.memberships
for update to authenticated
using (
  app_private.has_aal2()
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
);

drop policy if exists provider_connections_write on public.provider_connections;
create policy provider_connections_write on public.provider_connections
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
);

drop policy if exists organization_settings_write on public.organization_settings;
create policy organization_settings_write on public.organization_settings
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
);

drop policy if exists commission_statements_write on public.commission_statements;
create policy commission_statements_write on public.commission_statements
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
);

drop policy if exists commission_lines_write on public.commission_lines;
create policy commission_lines_write on public.commission_lines
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
);

drop policy if exists commission_exceptions_write on public.commission_exceptions;
create policy commission_exceptions_write on public.commission_exceptions
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','revenue']::public.member_role[])
);

drop policy if exists import_jobs_write on public.import_jobs;
create policy import_jobs_write on public.import_jobs
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);
