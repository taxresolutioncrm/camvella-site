# PRE-TARGET PACKAGE READY FOR SUPABASE EXECUTION

The branch contains the full pre-target implementation package: CRM/website sandbox, auth/runtime/data drivers, provider adapters, import tooling, 34 ordered SQL modules covering 53 tables, RLS and role boundaries, private Storage, portal access, audit/integrity guards, server RPCs, public intake/booking, current Edge Function auth, reporting/search, isolation tests, SEO handoff and deployment runbook.

## Next target-phase sequence
1. Select the dedicated Supabase project.
2. Execute SQL modules in order on that target.
3. Create deterministic test users/orgs/offices/roles.
4. Run tenant + office + assigned-book + role tests.
5. Run Storage matrix.
6. Run database advisors; fix all relevant findings.
7. Configure Auth/MFA and verify sessions/revocation.
8. Deploy Edge Functions and test bootstrap/invite/public endpoints.
9. Generate one clean timestamped migration after the target schema is green.
10. Connect browser with project URL + publishable key.
11. Connect providers one at a time.
12. Run end-to-end verification before production.

## External input required
The dedicated Supabase project target/ref.
