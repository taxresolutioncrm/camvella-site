# READY FOR SUPABASE HANDOFF

The branch now contains the complete pre-target package: frontend sandbox, provider adapters, domain schema, RLS, office scoping, Data API grants, Storage policies, audit triggers, integrity guards, server RPCs, Edge Function stubs, fixtures, import templates, isolation tests, SEO handoff, and deployment runbook.

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

## Required target-phase sequence
1. Select the dedicated Supabase project.
2. Apply migrations in order.
3. Verify Data API settings/grants.
4. Create two organizations, two offices, and test users/roles.
5. Run tenant and office isolation tests.
6. Run database advisors.
7. Resolve all relevant findings.
8. Verify private Storage and portal Storage policies.
9. Deploy trusted Edge Functions.
10. Test bootstrap/team invite/portal invite.
11. Connect browser with publishable key only.
12. Test CRUD and reporting views under each role.
13. Connect provider credentials one provider at a time.
14. Run end-to-end workflow verification.

## User input required
The dedicated Supabase project target/ref is the next external dependency.
