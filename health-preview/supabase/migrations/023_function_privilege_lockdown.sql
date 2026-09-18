-- 023_function_privilege_lockdown.sql
-- Explicitly locks SECURITY DEFINER functions after the full migration stack.
-- DO NOT APPLY until the dedicated Supabase project is selected.

-- Authenticated RLS helper functions.
revoke all on function app_private.current_org_ids() from public, anon;
grant execute on function app_private.current_org_ids() to authenticated;

revoke all on function app_private.has_org_role(uuid,public.member_role[]) from public, anon;
grant execute on function app_private.has_org_role(uuid,public.member_role[]) to authenticated;

revoke all on function app_private.can_access_office(uuid,uuid) from public, anon;
grant execute on function app_private.can_access_office(uuid,uuid) to authenticated;

revoke all on function app_private.is_portal_user_for_client(uuid) from public, anon;
grant execute on function app_private.is_portal_user_for_client(uuid) to authenticated;

revoke all on function app_private.portal_can_access_storage_object(text) from public, anon;
grant execute on function app_private.portal_can_access_storage_object(text) to authenticated;

revoke all on function app_private.can_manage_assignment(uuid,uuid,uuid) from public, anon;
grant execute on function app_private.can_manage_assignment(uuid,uuid,uuid) to authenticated;

revoke all on function app_private.can_view_client(uuid) from public, anon;
grant execute on function app_private.can_view_client(uuid) to authenticated;

revoke all on function app_private.can_view_sensitive_client(uuid) from public, anon;
grant execute on function app_private.can_view_sensitive_client(uuid) to authenticated;

revoke all on function app_private.can_manage_client(uuid) from public, anon;
grant execute on function app_private.can_manage_client(uuid) to authenticated;

-- Server-only public RPCs.
revoke all on function public.bootstrap_tenant(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.bootstrap_tenant(uuid,text,text,text) to service_role;

revoke all on function public.accept_team_invite(uuid,text,text) from public, anon, authenticated;
grant execute on function public.accept_team_invite(uuid,text,text) to service_role;

revoke all on function public.create_team_invitation(uuid,uuid,uuid,text,public.member_role,integer) from public, anon, authenticated;
grant execute on function public.create_team_invitation(uuid,uuid,uuid,text,public.member_role,integer) to service_role;

revoke all on function public.create_portal_invitation(uuid,uuid,text,integer) from public, anon, authenticated;
grant execute on function public.create_portal_invitation(uuid,uuid,text,integer) to service_role;

revoke all on function public.accept_portal_invitation(uuid,text,text) from public, anon, authenticated;
grant execute on function public.accept_portal_invitation(uuid,text,text) to service_role;

-- Trigger/internal helpers: never callable by browser roles.
revoke all on function app_private.audit_row_change() from public, anon, authenticated;
revoke all on function app_private.guard_last_admin() from public, anon, authenticated;
revoke all on function app_private.guard_enrollment_submission() from public, anon, authenticated;
revoke all on function app_private.guard_parent_organization() from public, anon, authenticated;
revoke all on function app_private.guard_user_organization() from public, anon, authenticated;
revoke all on function app_private.guard_enrollment_relationships() from public, anon, authenticated;
revoke all on function app_private.guard_policy_relationships() from public, anon, authenticated;
revoke all on function app_private.guard_client_parent(text,uuid,uuid) from public, anon, authenticated;
revoke all on function app_private.guard_client_linked_rows() from public, anon, authenticated;
revoke all on function app_private.guard_communication_thread_alignment() from public, anon, authenticated;
revoke all on function app_private.guard_plan_comparison_item() from public, anon, authenticated;

-- Ordinary trigger helper should not be called directly.
revoke all on function public.set_updated_at() from public, anon, authenticated;
