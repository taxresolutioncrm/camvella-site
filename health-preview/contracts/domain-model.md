# Domain Model

## Organization
- id
- name
- status
- created_at

## Office
- id
- organization_id
- name
- timezone
- phone
- email
- fax

## Client
- id
- organization_id
- office_id
- first_name
- last_name
- dob
- email
- phone
- market
- assigned_user_id
- portal_status
- renewal_risk
- created_at
- updated_at

## Household
- id
- organization_id
- client_id
- household_size
- annual_income
- state
- county
- subsidy_estimate
- eligibility_status

## Household Member
- id
- household_id
- first_name
- last_name
- dob
- relationship
- tobacco_use
- applicant_status

## Appointment
- id
- organization_id
- office_id
- lead_id nullable
- client_id nullable
- assigned_user_id
- appointment_type
- starts_at
- duration_minutes
- status
- outcome

## Enrollment
- id
- organization_id
- office_id
- client_id
- assigned_user_id
- market
- enrollment_type
- lifecycle_status
- eligibility_status
- carrier_id nullable
- carrier_product_id nullable
- submitted_at nullable
- effective_date nullable
- created_at
- updated_at

## Policy
- id
- organization_id
- office_id
- client_id
- enrollment_id nullable
- carrier_id
- carrier_product_id
- policy_number
- status
- effective_date
- termination_date nullable
- renewal_date nullable
- premium_amount nullable

## Service Request
- id
- organization_id
- office_id
- client_id
- policy_id nullable
- request_type
- source
- priority
- status
- assigned_user_id
- sla_due_at nullable
- created_at
- resolved_at nullable

## Renewal
- id
- organization_id
- office_id
- client_id
- policy_id
- market
- review_window_start
- review_window_end
- risk_level
- outreach_status
- appointment_id nullable
- outcome nullable

All tenant-owned records must resolve to organization_id.
