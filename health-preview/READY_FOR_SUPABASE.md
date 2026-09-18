# READY FOR SUPABASE TARGET PHASE

The branch contains the full pre-target package: CRM sandbox, auth shell, provider adapters, import tooling, 22 ordered migrations, RLS and office/assigned-book scoping, Data API grants, private Storage, portal access, audit/integrity guards, server RPCs, Edge Function stubs, reporting views, isolation tests, SEO handoff, and deployment runbook.

## Migration order
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

## Target-phase sequence
1. Select the dedicated Supabase project.
2. Apply migrations in order.
3. Confirm Data API settings and explicit grants.
4. Create test users/orgs/offices/roles.
5. Run tenant + office + assigned-book isolation tests.
6. Run database advisors and fix findings.
7. Test private Storage and portal Storage.
8. Deploy trusted Edge Functions.
9. Test bootstrap/team-invite/portal-invite.
10. Connect browser with publishable key.
11. Test CRUD, reports, auth/session, and role boundaries.
12. Connect providers one at a time.
13. Run end-to-end live workflow verification.

## User input required
The dedicated Supabase project target/ref is the next external dependency.
