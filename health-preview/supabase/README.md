# Supabase Handoff Package

Do not apply this work to an existing unrelated RomyLabs project.

## Pre-target SQL module order
1. 001_core_schema.sql
2. 002_comms_revenue_audit.sql
3. 003_rls.sql
4. 004_storage.sql
5. 005_platform_support.sql
6. 006_app_support.sql
7. 007_data_api_grants.sql
8. 008_audit_triggers.sql
9. 009_server_rpcs.sql
10. 010_office_access_hardening.sql
11. 011_workflow_guards.sql
12. 012_domain_completion.sql
13. 013_invitation_rpcs.sql
14. 014_settings_templates_preferences.sql
15. 015_data_integrity_indexes.sql
16. 016_reporting_views.sql
17. 017_security_cleanup_and_audit.sql
18. 018_tenant_integrity_triggers.sql
19. 019_domain_relationship_guards.sql
20. 020_communications_scheduling_completion.sql
21. 021_invite_history_and_market_guards.sql
22. 022_role_policy_alignment.sql
23. 023_function_privilege_lockdown.sql
24. 024_storage_role_alignment.sql
25. 025_public_forms_and_booking_rpcs.sql
26. 026_public_rate_limit_and_availability.sql
27. 027_search_and_activity.sql
28. 028_portal_privacy_and_task_roles.sql
29. 029_scheduling_and_invite_integrity.sql
30. 030_actor_and_attachment_integrity.sql
31. 031_public_slug_and_intake_integrity.sql
32. 032_external_ids_and_sync_jobs.sql
33. 033_active_assignment_guard.sql
34. 034_portal_account_visibility.sql
35. 035_membership_write_hardening.sql
36. 036_portal_invite_reuse.sql
37. 037_assignment_office_alignment.sql
38. 038_atomic_enrollment_case.sql
39. 039_workflow_artifacts_and_imports.sql
40. 040_import_storage.sql
41. 041_policy_event_and_campaign_role_alignment.sql
42. 042_import_job_role_alignment.sql
43. 043_commission_statement_storage.sql
44. 044_atomic_import_apply.sql
45. 045_atomic_commission_apply.sql
46. 046_import_storage_role_alignment.sql
47. 047_portal_data_boundary.sql
48. 048_portal_messages.sql
49. 049_portal_message_sender_guard.sql
50. 050_portal_least_privilege.sql
51. 051_portal_message_read_receipts.sql
52. 052_aal2_sensitive_writes.sql
53. 053_storage_aal2_alignment.sql
54. 054_portal_consent_and_request_alignment.sql
55. 055_storage_path_integrity.sql
56. 056_commission_storage_path_alignment.sql
57. 057_atomic_portal_messaging.sql
58. 058_public_intake_notes.sql
59. 059_public_booking_slot_enforcement.sql
60. 060_portal_storage_write_boundary.sql
61. 061_portal_invite_assignment_guard.sql
62. 062_storage_reference_uniqueness.sql
63. 063_member_deactivation_public_safety.sql
64. 064_team_invite_active_uniqueness.sql
65. 065_last_admin_guard.sql
66. 066_portal_account_single_active_user.sql
67. 067_concurrency_hardening.sql
68. 068_member_deletion_integrity.sql
69. 069_portal_storage_metadata_alignment.sql
70. 070_storage_office_alignment.sql
71. 071_portal_policy_least_privilege.sql

These are ordered pre-target SQL modules, not committed Supabase migration history yet.

## Correct target workflow
1. Select/create the dedicated Supabase project.
2. Execute these modules in order against that target.
3. Create real Auth users plus deterministic tenant/office/role fixtures.
4. Run tenant, role, office, assigned-book, portal, Storage, Auth, Edge Function, import, commission, and public-booking tests.
5. Run Supabase database advisors and resolve every relevant finding.
6. When the target schema is green, generate/pull one clean timestamped migration for source history.
7. Verify the final migration list on the target.
8. Connect browser runtime with project URL + publishable key only.
9. Deploy the checked-in Edge Functions/config.
10. Connect live providers one at a time.
11. Run complete end-to-end verification before production.

## Current package
- 58 public application/support tables
- 71 uniquely ordered pre-target SQL modules
- 44 CRM routes plus dedicated login, onboarding, MFA, recovery, invitation, booking, and client-portal surfaces
- 13 Edge Functions
- RLS/office/assigned-book role boundaries
- AAL2 guards for sensitive administration/revenue writes
- private Storage with agency/portal path separation
- append-only audit coverage and cross-tenant integrity guards
- atomic enrollment, import, commission, portal-message, and public-booking workflows
- concurrent invitation/admin/portal-thread serialization
- member deletion safely retires public endpoints
- shared portal Storage reads require explicit portal-visible metadata
- organization/office/entity Storage path alignment
- client-safe portal policy projection
- current @supabase/server@1.7.0 Edge auth model
- pinned supabase-js 2.116.0 browser loader
- public intake/booking rate limiting + honeypot handling
- provider adapters/import fixtures
- browser repository/runtime/Auth/live-view/action abstractions

## Security rules
- Every exposed application table has RLS.
- Authorization is membership/role based, never user_metadata.
- Agents are office-scoped and assigned-book scoped.
- Revenue is separated from household/provider/Rx/internal communications.
- Client portal receives only explicitly client-safe records and Storage paths.
- Cross-org parent and foreign-user references are blocked by database guards.
- UPDATE policies use USING + WITH CHECK.
- Audit rows are browser read-only.
- Invitation/token mutations are server-only.
- Provider events and integration sync writes are server-only.
- Sensitive administrative/revenue writes require AAL2.
- Future Data API objects remain explicit opt-in.
- SECURITY DEFINER helpers use fixed search_path plus explicit EXECUTE revokes/grants.
- Browser code never receives secret/service-role keys.

## Current blocker
The dedicated Supabase project/ref has not been selected. No SQL module has been executed anywhere.
