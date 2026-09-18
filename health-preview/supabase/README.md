# Supabase Handoff Package

Do not apply these files to an existing unrelated RomyLabs project.

## Order
1. Select/create the dedicated Supabase project.
2. Confirm project settings and Data API exposure.
3. Apply 001_core_schema.sql.
4. Apply 002_comms_revenue_audit.sql.
5. Apply 003_rls.sql.
6. Apply 004_storage.sql.
7. Apply 005_platform_support.sql.
8. Apply 006_app_support.sql.
9. Apply 007_data_api_grants.sql.
10. Create authenticated fixture users and memberships.
11. Load seed.sql if desired.
12. Replace tenant_isolation.sql fixture placeholders with real UUIDs.
13. Run database advisors and tenant-isolation tests.
14. Fix every advisor/test failure before app connection.
15. Connect frontend with project URL + publishable key only.
16. Keep secret/service-role credentials in trusted server/Edge Function contexts only.

## Security rules
- Every exposed tenant table has RLS.
- Authorization is membership/role based, not user_metadata.
- UPDATE policies require USING + WITH CHECK.
- Audit log is append-only at the app role.
- Provider event ledger has no authenticated write path.
- Storage paths begin with organization_id.
- Views use security_invoker=true.
- No service_role in frontend code.
- First tenant/admin bootstrap runs through a trusted server action.

## Current blocker
A dedicated Supabase project/ref has not been selected. No migration has been applied anywhere.
