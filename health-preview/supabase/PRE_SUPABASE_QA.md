# Pre-Supabase Static QA

Status: PREPARED FOR TARGET SELECTION

## Migration order
- 001_core_schema.sql
- 002_comms_revenue_audit.sql
- 003_rls.sql
- 004_storage.sql
- 005_platform_support.sql
- 006_app_support.sql
- 007_data_api_grants.sql

## Static checks completed
- Every exposed application table in the draft has an RLS enable statement.
- Tenant policies use organization membership predicates rather than authentication alone.
- Update-capable policies include USING and WITH CHECK.
- Authorization roles are stored in memberships / trusted application state, not user_metadata.
- Reporting views use security_invoker=true.
- Audit log has no authenticated UPDATE/DELETE grant path.
- Provider event ledger has no authenticated INSERT/UPDATE/DELETE policy.
- Storage object paths begin with organization_id.
- Explicit authenticated Data API grants are drafted.
- anon receives no table/sequence grants from this package.
- First-tenant bootstrap is defined as a trusted-server flow.
- Frontend preview contains no Supabase URL, service role, or secret key.
- Provider secrets are modeled as server-side secret references only.

## Cannot be verified before project selection
- SQL parse/apply on the target Postgres instance
- Actual Data API exposure/settings
- Auth JWT fixtures
- RLS allow/deny behavior
- Storage upload/read/update/delete behavior
- Database advisors
- Function/view privilege behavior
- Edge Function/provider secret wiring

Those items require the dedicated Supabase target.
