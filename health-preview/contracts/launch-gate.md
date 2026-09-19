# Launch Gate

## Product
- [x] Major CRM route coverage
- [x] Collapsible persistent navigation
- [x] ACA workflow screens
- [x] Medicare workflow screens
- [x] Communications suite
- [x] Commission operations
- [x] Carrier operations
- [x] Compliance workspace
- [x] Client portal workflow
- [x] Public-site redesign
- [x] Public lead capture
- [x] Public booking workflow
- [x] Login / recovery / MFA / onboarding / invitation flows
- [ ] Final product name/domain

## Pre-target backend
- [x] 58-table domain model
- [x] 69 uniquely ordered SQL modules
- [x] provider adapter contracts
- [x] 13 Edge Functions
- [x] current Edge Function auth model
- [x] browser Supabase driver/runtime/action/live-view factory
- [x] RLS/office/assigned-book role design
- [x] AAL2 sensitive-write guards
- [x] Storage agency/portal/AAL2/path integrity design
- [x] audit/integrity/workflow guards
- [x] concurrency serialization guards for invitations, final-admin protection and portal threads
- [x] member-deletion/public-endpoint retirement guards
- [x] portal Storage metadata/read alignment
- [x] atomic enrollment/import/commission/portal-message workflows
- [x] public intake/availability/booking/rate-limit design
- [x] tenant/role/portal/Storage test matrices
- [ ] Dedicated Supabase project selected

## Target execution
- [ ] SQL modules execute successfully
- [ ] deterministic Auth/tenant/portal fixtures created
- [ ] RLS/role/Storage/AAL2 tests pass
- [ ] database advisors clean/reviewed
- [ ] Auth/MFA runtime verified
- [ ] all Edge Functions deployed/tested
- [ ] public intake/booking verified
- [ ] portal invite/upload/message/request flow verified
- [ ] import/commission atomic workflows verified
- [ ] one clean timestamped migration generated
- [ ] frontend connected
- [ ] providers connected/tested

## Release
- [ ] Final domain/product identity
- [ ] Production SEO canonicals
- [ ] One production release
- [ ] Live post-deploy verification
