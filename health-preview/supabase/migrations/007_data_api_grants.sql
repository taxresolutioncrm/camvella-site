-- 007_data_api_grants.sql
-- Explicit Data API grants for new Supabase projects.
-- RLS remains the row-authorization layer; GRANT controls API reachability.

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
grant usage on schema public to authenticated;

grant select on public.organizations, public.offices, public.memberships, public.carriers, public.carrier_products to authenticated;
grant select,insert,update on public.leads, public.clients, public.households, public.household_members, public.enrollments, public.policies to authenticated;
grant select,insert,update,delete on public.appointments, public.enrollment_evidence, public.service_requests, public.renewals, public.communication_threads, public.communications, public.documents, public.consent_records, public.tasks, public.carrier_contracts, public.commission_statements, public.commission_lines, public.commission_exceptions to authenticated;
grant select,insert on public.policy_events, public.audit_log to authenticated;
grant select,insert,update on public.user_profiles to authenticated;
grant select,insert,update,delete on public.team_invitations, public.notification_preferences, public.automation_rules, public.portal_invitations to authenticated;
grant select,update on public.app_notifications to authenticated;
grant select on public.provider_connections, public.provider_event_ledger to authenticated;
grant select on public.v_open_enrollment_queue, public.v_commission_exception_queue, public.v_renewal_queue to authenticated;

alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public grant select,insert,update,delete on tables to authenticated;