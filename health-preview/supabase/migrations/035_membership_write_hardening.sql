-- 035_membership_write_hardening.sql
-- Membership creation is invitation/bootstrap server-only; browser admins may only update existing members.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists memberships_write on public.memberships;

create policy memberships_update on public.memberships
for update to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
)
with check (
  app_private.has_org_role(organization_id,array['agency_admin']::public.member_role[])
);

revoke insert,delete on public.memberships from authenticated;
grant select,update on public.memberships to authenticated;

-- New memberships are created only by bootstrap/invitation service-role RPCs.
