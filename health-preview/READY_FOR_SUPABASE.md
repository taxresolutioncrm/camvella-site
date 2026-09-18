# READY FOR SUPABASE

The pre-Supabase package contains the frontend sandbox, provider adapters, schema, RLS design, storage design, Data API grants, import fixtures, security tests, and deployment handoff.

## Apply order
1. 001_core_schema.sql
2. 002_comms_revenue_audit.sql
3. 003_rls.sql
4. 004_storage.sql
5. 005_platform_support.sql
6. 006_app_support.sql
7. 007_data_api_grants.sql

## Immediately after apply
1. Confirm Data API exposure/settings.
2. Create auth fixture users in separate organizations.
3. Replace USER_A / USER_B / ORG_A / ORG_B in tenant_isolation.sql.
4. Run tenant isolation tests.
5. Run database advisors.
6. Fix every relevant security/performance finding.
7. Verify Storage SELECT/INSERT/UPDATE/DELETE across same-org and cross-org users.
8. Exercise trusted tenant bootstrap and invitation acceptance.
9. Connect frontend with project URL + publishable key only.
10. Configure server/Edge secrets for providers.
11. Run live provider and end-to-end workflow verification.

## Do not
- use an existing unrelated RomyLabs Supabase project
- put service_role or secret keys in frontend source
- allow browser-side self-assignment of agency_admin
- skip isolation testing
- call deployment complete before live verification

## User input required
Only the dedicated Supabase project target/ref is required to begin the backend phase.
