# Target Test Fixture Plan

Create these only in the dedicated test/sandbox Supabase project.

## Organizations
- ORG_A with OFFICE_A and OFFICE_B
- ORG_B with OFFICE_C

## Auth users / memberships in ORG_A
- ADMIN_USER: agency_admin, AAL2-capable
- MANAGER_USER: manager, AAL2-capable
- AGENT_A_USER: agent, OFFICE_A
- AGENT_B_USER: agent, OFFICE_B
- COMPLIANCE_USER: compliance, AAL2-capable
- REVENUE_USER: revenue, AAL2-capable

## Portal user
- PORTAL_USER linked only to PORTAL_CLIENT through client_portal_accounts.
- IDENTITY_MODE_USER with no memberships/portal account initially, used to prove staff-vs-portal mode exclusivity.

## Minimum records
- CLIENT_AGENT_A assigned to AGENT_A_USER / OFFICE_A
- CLIENT_AGENT_B assigned to AGENT_B_USER / OFFICE_B
- PORTAL_CLIENT in ORG_A
- one ORG_B client for cross-org denial tests
- one ACA enrollment + initialized/complete evidence for CLIENT_AGENT_A
- one active policy for CLIENT_AGENT_A
- one portal-visible policy for PORTAL_CLIENT
- one internal document, one portal-upload document, and one shared document for PORTAL_CLIENT
- one internal communication for CLIENT_AGENT_A
- one portal message thread for PORTAL_CLIENT
- one commission statement + matched line assigned to AGENT_A_USER
- one commission exception
- one client/provider/prescription/pharmacy set
- one carrier contract and agent license
- one appointment type + availability rule + booking link assigned to AGENT_A_USER
- one public intake form assigned to AGENT_A_USER
- one communication endpoint assigned to AGENT_A_USER
- one import staging job/file fixture
- one provider connection fixture with no live secret for readiness tests

## Deactivation fixture
Before the member-deactivation test, AGENT_A_USER should own the booking link,
availability rule, public intake assignment, and communication endpoint above.
The test transaction must roll back after verifying those public-facing references
are disabled/unassigned before the membership becomes inactive.

Use deterministic UUIDs so SQL test files can be parameterized once.


## Identity-mode target tests
- Bootstrap two simultaneous requests for IDENTITY_MODE_USER; exactly one workspace may be created.
- Activate a client portal for IDENTITY_MODE_USER, then prove team-invite acceptance is rejected.
- Deactivate the portal account, accept a team invitation, then prove portal-invite acceptance is rejected while the team membership is active.
- Confirm PORTAL_USER can read policy data only through list_my_portal_policies(), not direct policies SELECT.
