# Pre-Supabase Static QA

Status: PRE-TARGET HARDENING GATE

## Package inventory
- 58 public application/support tables
- 91 uniquely ordered SQL modules
- 44 CRM routes / 45 routed CRM views
- dedicated website, booking, login, onboarding, invite acceptance, password recovery, MFA, and client-portal surfaces
- 14 Edge Functions
- current @supabase/server@1.7.0 auth pattern
- pinned browser supabase-js 2.116.0
- Auth/MFA configuration gate
- tenant, role, Storage, public endpoint, provider, import, commission, portal and deployment handoffs

## Static checks completed
- Every current public table has an RLS-enable statement.
- UPDATE policies use USING + WITH CHECK.
- Reporting/activity views use security_invoker.
- Organization, office, assigned-book and role boundaries are modeled.
- Portal users are separated from internal client, communications, consent, evidence and agency-only document access.
- Portal policy rows are exposed through a client-safe projection RPC.
- Portal document paths distinguish agency / portal / shared visibility.
- Cross-org parent/user references and Storage path mismatches are guarded.
- Private Storage paths are aligned to organization, office and entity context.
- Active assignments cannot target disabled team members or cross-office agents.
- Final agency admin cannot be removed/deactivated.
- Agency staff identities and active client-portal identities are mutually exclusive.
- First-tenant bootstrap is serialized per Auth user.
- Member deletion safely retires public booking/availability/communication endpoints.
- Portal shared-file reads require matching portal-visible document metadata.
- Enrollment creation/evidence initialization is atomic.
- Bulk imports and commission statement application are atomic.
- Appointment overlap is blocked.
- Concurrent team/portal invite, final-admin, and portal-thread races are serialized.
- Public booking is restricted to configured availability slots.
- Public booking/intake use server-resolved slugs rather than browser tenant IDs.
- Public endpoints use hashed-IP database rate limits plus honeypot handling.
- Client portal profile/service-request/message APIs are least-privilege.
- Sensitive admin/revenue database and Storage writes require AAL2.
- Public/webhook Edge Functions use verify_jwt=false + auth:none intentionally.
- Authenticated Edge Functions use verify_jwt=true + auth:user.
- Edge SDK versions are pinned.
- Data API grants are explicit and future objects are opt-in.
- SECURITY DEFINER search_path/EXECUTE boundaries have been statically reviewed.
- Frontend preview contains no project URL, service-role key or secret key.
- Preview surfaces remain noindex.

## Requires the dedicated target
- SQL parser/apply execution on the target Postgres version
- real Auth users/JWT sessions and AAL1/AAL2 behavior
- RLS allow/deny runtime tests for every role
- Storage API matrix
- database advisors
- Edge Function deployment/runtime
- public intake/availability/booking HTTP tests
- portal invite/upload/message/request tests
- atomic import/commission tests
- provider credentials/webhook signature tests
- final end-to-end workflows
