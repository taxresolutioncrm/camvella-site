# Health Insurance CRM — Integration Contract

Sandbox architecture only. No live Supabase project is referenced.

## Core data domains
- organizations
- offices
- users
- user_roles
- leads
- clients
- households
- household_members
- appointments
- enrollments
- enrollment_evidence
- policies
- policy_events
- service_requests
- communications
- communication_threads
- documents
- consent_records
- tasks
- carriers
- carrier_contracts
- carrier_products
- commissions
- commission_statements
- commission_lines
- commission_exceptions
- renewals
- audit_log

## Tenant boundary
Every tenant-owned row must resolve to an organization_id. Office-scoped records additionally carry office_id. Cross-organization access must be blocked by RLS.

## Roles
- agency_admin
- manager
- agent
- compliance
- revenue

## Enrollment lifecycle
draft -> needs_review -> ready -> submitted -> pending -> approved -> active
Terminal states: denied, cancelled

## Communication channels
email, phone, sms, fax, voicemail, portal

Each communication event should capture:
- organization_id
- office_id
- client_id nullable
- lead_id nullable
- thread_id
- channel
- direction
- provider_message_id nullable
- provider_status
- from_address
- to_address
- subject nullable
- body_preview
- recording_ref nullable
- document_ref nullable
- created_by
- created_at

## Provider adapter boundaries
### Marketplace
getPlans()
checkEligibility()
getProviderDirectory()
checkDrugCoverage()

### Messaging
sendEmail()
sendSms()
placeCall()
sendFax()
fetchInboundEvents()

### Carrier
syncProducts()
syncContracting()
syncEnrollmentStatus()
syncCommissionStatement()

## Security gates before production
- RLS enabled on all exposed tenant tables
- USING and WITH CHECK for update policies
- no service role in frontend
- app_metadata for authorization claims
- security_invoker on exposed views
- cross-org SELECT/INSERT/UPDATE/DELETE tests
- audit coverage for privileged mutations
