-- 034_portal_account_visibility.sql
-- Limits portal-account visibility to the client, management, or assigned agent.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists client_portal_accounts_select on public.client_portal_accounts;

create policy client_portal_accounts_select on public.client_portal_accounts
for select to authenticated
using (
  user_id=(select auth.uid())
  or app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or app_private.can_manage_client(client_id)
);
