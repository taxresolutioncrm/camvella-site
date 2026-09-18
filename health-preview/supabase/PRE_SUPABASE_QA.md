# Pre-Supabase Static QA

Status: HARDENED PRE-TARGET PACKAGE

## Current package
- 22 ordered migrations
- browser repository + workspace/auth abstractions
- Edge Function stubs for bootstrap/invites/webhooks
- provider adapters and simulation fixtures
- import templates and validators
- tenant, office, workflow, relationship, market, and role-policy guards
- reporting views and operational indexes
- login preview and CRM sandbox

## Static design checks
- All current public application tables are intended to have RLS.
- Explicit authenticated Data API grants are defined.
- Future tables/functions default to no anon/authenticated exposure.
- Organization + office + assigned-book boundaries are modeled.
- Revenue is separated from sensitive household/provider/Rx data.
- Parent and user cross-tenant references are rejected.
- Enrollment submission requires an initialized, complete required-evidence checklist.
- Final agency administrator cannot be removed/deactivated.
- Team/portal invitation mutation is server-only.
- Client portal has scoped record and document access.
- Provider event ledger is server-write only.
- Audit coverage spans core and sensitive operational mutations.
- Reporting views use security_invoker.
- Frontend contains no project URL, secret key, or service-role key.

## Requires the dedicated Supabase project
- SQL parse/apply on target Postgres
- Auth users/JWT fixtures
- Live RLS allow/deny execution
- Storage API tests
- database advisors
- function privilege verification
- Edge Function runtime verification
- live provider secret wiring
