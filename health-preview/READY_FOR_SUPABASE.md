# READY FOR SUPABASE

Everything that can be prepared without a live project is now in the preview branch.

## Apply order
1. 001_core_schema.sql
2. 002_comms_revenue_audit.sql
3. 003_rls.sql
4. 004_storage.sql
5. 005_platform_support.sql

## Immediately after apply
1. Confirm Data API exposure/grants.
2. Create two auth fixture users in separate organizations.
3. Replace USER_A / USER_B / ORG_A / ORG_B in tenant_isolation.sql.
4. Run tenant isolation tests.
5. Run database advisors.
6. Fix every security/performance finding relevant to the new schema.
7. Verify Storage SELECT/INSERT/UPDATE/DELETE across same-org and cross-org users.
8. Connect frontend with project URL + publishable key only.
9. Configure server/Edge secrets for providers.
10. Run live provider and end-to-end workflow verification.

## Do not
- use an existing unrelated RomyLabs Supabase project
- put service_role or secret keys in frontend source
- skip isolation testing
- call deployment complete before live verification

## User input required
Only the dedicated Supabase project target/ref is required to begin the backend phase.
