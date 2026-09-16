# Supabase Handoff Package

Do not apply these files to an existing RomyLabs project.

## Order
1. Select/create the dedicated Supabase project.
2. Confirm project settings and Data API exposure.
3. Apply 001_core_schema.sql.
4. Apply 002_comms_revenue_audit.sql.
5. Apply 003_rls.sql.
6. Apply 004_storage.sql.
7. Add authenticated test users and memberships.
8. Load seed.sql if desired.
9. Replace tenant_isolation.sql placeholders with real JWT/auth fixtures.
10. Run Supabase database advisors and RLS tests.
11. Fix every advisor/test failure before app connection.
12. Connect frontend with publishable key only.
13. Keep secret/service-role credentials in trusted server/Edge Function contexts only.

## Security rules
- Every exposed tenant table has RLS.
- Authorization is membership/role based, not user_metadata.
- UPDATE policies require USING + WITH CHECK.
- Audit log is append-only at the app role.
- Storage paths begin with organization_id.
- Views must use security_invoker=true.
- No service_role in frontend code.

## Current blocker
A dedicated Supabase project/ref has not been selected. No migration has been applied anywhere.
