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
20. 020_communications_scheduling_completion.sql
21. 021_invite_history_and_market_guards.sql
22. 022_role_policy_alignment.sql

## After migrations
1. Confirm Data API exposure/settings.
2. Create authenticated fixture users in separate organizations/offices.
3. Load seed data if desired.
4. Replace isolation-test fixture UUIDs.
5. Run T1-T11 tenant/office/assigned-book isolation tests.
6. Run database advisors.
7. Fix every relevant security/performance finding.
8. Verify private Storage for agency and portal users.
9. Exercise tenant bootstrap, team invite, and portal invite flows.
10. Deploy trusted Edge Functions.
11. Connect frontend with project URL + publishable key only.
12. Test CRUD/reporting under every role.
13. Connect provider credentials one provider at a time.
14. Run end-to-end live workflow verification.

## Security rules
- Every exposed table has RLS.
- Authorization is membership/role based, never user_metadata.
- Agents are office-scoped and assigned-book scoped.
- Compliance and revenue permissions are separated from sensitive client data.
- Cross-org parent references and foreign user assignments are blocked by database triggers.
- UPDATE policies use USING + WITH CHECK.
- Audit rows are trigger/server generated and append-only to browser roles.
- Invitation writes are server-only.
- Provider event ingestion is idempotent and server-only.
- Storage is private; portal users only access their client-document path.
- Reporting views use security_invoker=true.
- Future Data API objects remain explicit opt-in.
- Browser uses project URL + publishable key only.

## Current blocker
A dedicated Supabase project/ref has not been selected. No migration has been applied anywhere.
