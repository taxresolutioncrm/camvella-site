# PRE-TARGET PACKAGE READY FOR SUPABASE EXECUTION

The isolated branch contains the complete pre-target implementation package: CRM/website sandbox, booking flow, login/onboarding/recovery/MFA, client portal, auth/runtime/data/live-view/action drivers, provider adapters, import tooling, 90 uniquely ordered SQL modules covering 58 tables, RLS and role boundaries, AAL2 guards, private Storage, audit/integrity guards, atomic server workflows, public intake/booking, Edge Function auth, reporting/search, isolation tests, SEO handoff and deployment runbook.

## Next target-phase sequence
1. Select the dedicated Supabase project.
2. Execute all 91 SQL modules in order on that target.
3. Create deterministic Auth users/orgs/offices/roles/portal fixtures.
4. Run tenant + office + assigned-book + role + portal tests.
5. Run Storage path/role/AAL2 matrix.
6. Run database advisors; fix every relevant finding.
7. Configure Auth/MFA/redirects and verify session/revocation behavior.
8. Deploy all 14 Edge Functions and test bootstrap/invite/public/import/commission/communication endpoints.
9. Generate one clean timestamped migration after the target schema is green.
10. Connect browser runtime using only project URL + publishable key.
11. Connect providers one at a time.
12. Run end-to-end sandbox verification before any production release.

## External input required
The dedicated Supabase project target/ref.
