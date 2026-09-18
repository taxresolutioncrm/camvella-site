# Supabase Handoff Package

Do not apply this work to an existing unrelated RomyLabs project.

## Pre-target SQL module order
1. 001_core_schema.sql
2. 002_comms_revenue_audit.sql
3. 003_rls.sql
4. 004_storage.sql
5. 005_platform_support.sql
6. 006_app_support.sql
7. 007_data_api_grants.sql
8. 008_audit_triggers.sql
9. 009_server_rpcs.sql
10. 010_office_access_hardening.sql
11. 011_workflow_guards.sql
12. 012_domain_completion.sql
13. 013_invitation_rpcs.sql
14. 014_settings_templates_preferences.sql
15. 015_data_integrity_indexes.sql
16. 016_reporting_views.sql
17. 017_security_cleanup_and_audit.sql
18. 018_tenant_integrity_triggers.sql
19. 019_domain_relationship_guards.sql
20. 020_communications_scheduling_completion.sql
21. 021_invite_history_and_market_guards.sql
22. 022_role_policy_alignment.sql
23. 023_function_privilege_lockdown.sql
24. 024_storage_role_alignment.sql
25. 025_public_forms_and_booking_rpcs.sql
26. 026_public_rate_limit_and_availability.sql
27. 027_search_and_activity.sql
28. 028_portal_privacy_and_task_roles.sql
29. 029_scheduling_and_invite_integrity.sql
30. 030_actor_and_attachment_integrity.sql
31. 031_public_slug_and_intake_integrity.sql
32. 032_external_ids_and_sync_jobs.sql
33. 033_active_assignment_guard.sql
34. 034_portal_account_visibility.sql

These are ordered pre-target SQL modules, not committed Supabase migration history yet.

## Correct target workflow
1. Select/create the dedicated Supabase project.
2. Use SQL execution against that target to apply/iterate the modules in order.
3. Create real auth/tenant fixtures.
4. Run RLS, role, office, assigned-book, Storage, Auth, Edge Function, and public endpoint tests.
5. Run Supabase database advisors and resolve all relevant findings.
6. When the target schema is green, generate/pull one clean timestamped migration for source history.
7. Verify local migration list.
8. Connect browser runtime with project URL + publishable key only.
9. Deploy Edge Functions using the checked-in function config.
10. Connect live providers one at a time.
11. Run complete end-to-end verification before production.

## Current package
- 53 public application/support tables
- 34 ordered SQL modules
- RLS/office/assigned-book role boundaries
- private Storage + portal document access
- append-only audit trigger design
- server-only bootstrap/invitation/public booking RPCs
- current @supabase/server@1.7.0 Edge auth model
- pinned supabase-js 2.116.0 browser loader
- public endpoint rate limiting
- tenant/role/Storage test plans
- provider adapters/import fixtures
- browser repository/runtime/Auth abstractions

## Security rules
- Every exposed application table has RLS.
- Authorization is membership/role based, never user_metadata.
- Agents are office-scoped and assigned-book scoped.
- Revenue is separated from household/provider/Rx/internal communications.
- Client portal cannot read internal agency communications/evidence.
- Cross-org parent and foreign-user references are blocked by database guards.
- UPDATE policies use USING + WITH CHECK.
- Audit rows are browser read-only.
- Invitation/token mutations are server-only.
- Provider events and integration sync writes are server-only.
- Future Data API objects remain explicit opt-in.
- SECURITY DEFINER helpers have fixed search_path and explicit EXECUTE revokes/grants.
- Browser never receives secret/service-role keys.

## Current blocker
The dedicated Supabase project/ref has not been selected. No SQL module has been executed anywhere.
