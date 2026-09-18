# Pre-Supabase Static QA

Status: PRE-TARGET HARDENING GATE

## Package inventory
- 53 public application/support tables
- 34 ordered SQL modules
- 44 CRM routes / 45 routed views
- 9 Edge Functions
- current @supabase/server@1.7.0 auth pattern
- pinned browser supabase-js 2.116.0
- Auth/MFA configuration gate
- tenant, role, Storage, public endpoint, provider and deployment handoffs

## Static checks completed
- RLS enablement drafted for every current public table.
- UPDATE policies include USING + WITH CHECK.
- Reporting/activity views use security_invoker.
- Organization, office, assigned-book and role boundaries are modeled.
- Portal users are separated from internal communications/evidence.
- Cross-org parent and user references are guarded.
- Active assignments cannot target disabled team members.
- Final agency admin cannot be removed/deactivated.
- Enrollment submission requires initialized complete evidence.
- Appointment overlap is blocked.
- Public booking/intake use server-resolved slugs, not browser-supplied tenant IDs.
- Public endpoints use hashed-IP DB rate limits.
- Public/webhook Edge Functions use verify_jwt=false + auth:none intentionally.
- Authenticated Edge Functions use verify_jwt=true + auth:user.
- Edge package versions are pinned.
- Data API grants are explicit and future objects are opt-in.
- Function search_path and EXECUTE boundaries have been statically reviewed.
- Frontend preview contains no project URL, service-role key or secret key.
- Preview surfaces remain noindex.

## Requires the dedicated target
- SQL parser/apply execution on the real Postgres version
- actual Data API table/function exposure toggles
- auth users/JWT sessions
- RLS allow/deny runtime behavior
- Storage API runtime behavior
- database advisors
- Edge Function deployment/runtime
- MFA/session behavior
- provider credentials/webhook signatures
- final end-to-end workflows
