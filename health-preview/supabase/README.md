# Supabase Handoff Package

Do not apply these files to an existing unrelated RomyLabs project.

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

## After migrations
1. Confirm Data API exposure/settings.
2. Create authenticated fixture users in separate organizations/offices.
3. Load seed data if desired.
4. Replace isolation-test fixture UUIDs.
5. Run T1-T11 isolation tests.
6. Run database advisors.
7. Fix every relevant security/performance finding.
8. Verify Storage access for agency users and portal users.
9. Exercise tenant bootstrap, team invite, and portal invite flows.
10. Connect frontend with project URL + publishable key only.
11. Configure Edge Function server secret and provider credentials.
12. Run end-to-end live workflow verification.

## Security rules
- Every exposed table has RLS.
- Authorization is membership/role based, never user_metadata.
- Agents are office-scoped; operational roles are org-wide where defined.
- Cross-org parent references are rejected by database triggers.
- UPDATE policies use USING + WITH CHECK.
- Audit rows are trigger/server generated and append-only to clients.
- Invitation writes are server-only.
- Provider event ingestion is idempotent and server-only.
- Storage is private; portal users only access their own client-document path.
- Views use security_invoker=true.
- Future Data API objects remain explicit opt-in.
- No secret/service-role key is browser-exposed.

## Current blocker
A dedicated Supabase project/ref has not been selected. No migration has been applied anywhere.
