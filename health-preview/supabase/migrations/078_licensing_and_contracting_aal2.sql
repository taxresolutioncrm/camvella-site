-- 078_licensing_and_contracting_aal2.sql
-- Licensing/carrier appointment changes are sensitive operational configuration.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists agent_licenses_write on public.agent_licenses;
create policy agent_licenses_write on public.agent_licenses
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager','compliance']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager','compliance']::public.member_role[]
  )
);

drop policy if exists carrier_contracts_write on public.carrier_contracts;
create policy carrier_contracts_write on public.carrier_contracts
for all to authenticated
using (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager','compliance']::public.member_role[]
  )
)
with check (
  app_private.has_aal2()
  and organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(
    organization_id,
    array['agency_admin','manager','compliance']::public.member_role[]
  )
);
