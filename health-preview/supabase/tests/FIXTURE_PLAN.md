# Target Test Fixture Plan

Create these only in the dedicated test/sandbox Supabase project.

## Organizations
- ORG_A with OFFICE_A and OFFICE_B
- ORG_B with OFFICE_C

## Auth users / memberships in ORG_A
- ADMIN_USER: agency_admin
- MANAGER_USER: manager
- AGENT_A_USER: agent, OFFICE_A
- AGENT_B_USER: agent, OFFICE_B
- COMPLIANCE_USER: compliance
- REVENUE_USER: revenue

## Portal user
- PORTAL_USER linked only to PORTAL_CLIENT through client_portal_accounts.

## Minimum records
- CLIENT_AGENT_A assigned to AGENT_A_USER / OFFICE_A
- CLIENT_AGENT_B assigned to AGENT_B_USER / OFFICE_B
- PORTAL_CLIENT in ORG_A
- one ACA enrollment + complete evidence for CLIENT_AGENT_A
- one active policy for CLIENT_AGENT_A
- one communication for CLIENT_AGENT_A
- one commission statement + line assigned to AGENT_A_USER
- one commission exception
- one client/provider/prescription/pharmacy set
- one carrier contract and agent license
- one record in ORG_B for cross-org denial tests

Use deterministic UUIDs so SQL test files can be parameterized once.
