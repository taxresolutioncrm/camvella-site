# Pre-Supabase Static QA

Status: READY FOR TARGET SELECTION

## Migration order
- 001_core_schema.sql
- 002_comms_revenue_audit.sql
- 003_rls.sql
- 004_storage.sql
- 005_platform_support.sql

## Static checks completed
- Every exposed application table in the draft has an RLS enable statement.
- Tenant policies use organization membership predicates rather than authentication alone.
- Update-capable policies include USING and WITH CHECK.
- Authorization roles are stored in memberships / app-controlled data, not user_metadata.
- Reporting views use security_invoker=true.
- Audit log has no authenticated UPDATE/DELETE grant path.
- Provider event ledger has no authenticated INSERT/UPDATE/DELETE policy.
- Storage object paths begin with organization_id.
- Frontend preview contains no Supabase URL, service role, or secret key.
- Provider secrets are modeled as server-side secret references only.

## Cannot be verified before project selection
- SQL parse/apply on target Postgres version
- Data API exposure/grants
- Auth JWT fixtures
- RLS allow/deny behavior
- Storage upload/read/update/delete behavior
- Database advisors
- Function/view privileges
- Edge Function/provider secret wiring

Those items are the Supabase handoff gate.
