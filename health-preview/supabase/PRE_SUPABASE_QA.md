# Pre-Supabase Static QA

Status: HARDENING COMPLETE; TARGET EXECUTION PENDING

## Migration count
19

## Static design checks
- Full UI-backed domain coverage drafted.
- RLS enabled for all exposed application tables.
- Organization + office tenant boundaries modeled.
- Cross-organization parent-reference guards defined.
- Cross-organization user-assignment guards defined.
- Enrollment evidence gate defined.
- Final-admin protection defined.
- Invitation token generation/acceptance is server-only.
- Explicit Data API grants drafted; future objects default to no authenticated/anon access.
- Reporting views use security_invoker=true.
- Audit trigger coverage expanded across sensitive mutations.
- Provider event ledger is server-write only.
- Storage includes org-scoped agency policies and portal client-document policies.
- Edge Function stubs exist for tenant bootstrap and invitation flows.
- Frontend contains no project URL, secret key, or service-role key.

## Requires the dedicated Supabase project
- SQL parse/apply on target Postgres
- Auth users/JWT fixtures
- Actual RLS allow/deny execution
- Storage API tests
- Database advisors
- Function privilege verification
- Edge Function deployment/runtime verification
- Provider secret wiring

No existing RomyLabs Supabase project should be used for these tests.
