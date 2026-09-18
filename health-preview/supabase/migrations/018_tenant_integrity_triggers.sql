-- 018_tenant_integrity_triggers.sql
-- Rejects cross-organization parent references and foreign user assignments.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_parent_organization()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  parent_table text := tg_argv[0];
  parent_column text := tg_argv[1];
  parent_id uuid;
  parent_org uuid;
begin
  begin
    parent_id := nullif(to_jsonb(new)->>parent_column,'')::uuid;
  exception when others then
    raise exception 'invalid parent id in %.%',tg_table_name,parent_column;
  end;

  if parent_id is null then
    return new;
  end if;

  execute format('select organization_id from public.%I where id=$1',parent_table)
  into parent_org
  using parent_id;

  if parent_org is null then
    raise exception 'parent % % not found',parent_table,parent_id;
  end if;

  if parent_org <> new.organization_id then
    raise exception 'cross-organization parent reference rejected for %.%',tg_table_name,parent_column;
  end if;

  return new;
end;
$$;
revoke all on function app_private.guard_parent_organization() from public, anon, authenticated;

create or replace function app_private.guard_user_organization()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  user_column text := tg_argv[0];
  target_user uuid;
begin
  begin
    target_user := nullif(to_jsonb(new)->>user_column,'')::uuid;
  exception when others then
    raise exception 'invalid user id in %.%',tg_table_name,user_column;
  end;

  if target_user is null then
    return new;
  end if;

  if not exists (
    select 1 from public.memberships m
    where m.organization_id=new.organization_id
      and m.user_id=target_user
  ) then
    raise exception 'user assignment is outside the record organization';
  end if;

  return new;
end;
$$;
revoke all on function app_private.guard_user_organization() from public, anon, authenticated;

create trigger tenant_memberships_office_id before insert or update on public.memberships
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_leads_office_id before insert or update on public.leads
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_clients_office_id before insert or update on public.clients
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_households_client_id before insert or update on public.households
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_household_members_household_id before insert or update on public.household_members
for each row execute function app_private.guard_parent_organization('households','household_id');
create trigger tenant_appointments_office_id before insert or update on public.appointments
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_appointments_lead_id before insert or update on public.appointments
for each row execute function app_private.guard_parent_organization('leads','lead_id');
create trigger tenant_appointments_client_id before insert or update on public.appointments
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_carrier_products_carrier_id before insert or update on public.carrier_products
for each row execute function app_private.guard_parent_organization('carriers','carrier_id');
create trigger tenant_enrollments_office_id before insert or update on public.enrollments
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_enrollments_client_id before insert or update on public.enrollments
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_enrollments_carrier_id before insert or update on public.enrollments
for each row execute function app_private.guard_parent_organization('carriers','carrier_id');
create trigger tenant_enrollments_carrier_product_id before insert or update on public.enrollments
for each row execute function app_private.guard_parent_organization('carrier_products','carrier_product_id');
create trigger tenant_enrollment_evidence_enrollment_id before insert or update on public.enrollment_evidence
for each row execute function app_private.guard_parent_organization('enrollments','enrollment_id');
create trigger tenant_policies_office_id before insert or update on public.policies
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_policies_client_id before insert or update on public.policies
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_policies_enrollment_id before insert or update on public.policies
for each row execute function app_private.guard_parent_organization('enrollments','enrollment_id');
create trigger tenant_policies_carrier_id before insert or update on public.policies
for each row execute function app_private.guard_parent_organization('carriers','carrier_id');
create trigger tenant_policies_carrier_product_id before insert or update on public.policies
for each row execute function app_private.guard_parent_organization('carrier_products','carrier_product_id');
create trigger tenant_policy_events_policy_id before insert or update on public.policy_events
for each row execute function app_private.guard_parent_organization('policies','policy_id');
create trigger tenant_service_requests_office_id before insert or update on public.service_requests
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_service_requests_client_id before insert or update on public.service_requests
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_service_requests_policy_id before insert or update on public.service_requests
for each row execute function app_private.guard_parent_organization('policies','policy_id');
create trigger tenant_renewals_office_id before insert or update on public.renewals
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_renewals_client_id before insert or update on public.renewals
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_renewals_policy_id before insert or update on public.renewals
for each row execute function app_private.guard_parent_organization('policies','policy_id');
create trigger tenant_renewals_appointment_id before insert or update on public.renewals
for each row execute function app_private.guard_parent_organization('appointments','appointment_id');
create trigger tenant_communication_threads_office_id before insert or update on public.communication_threads
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_communication_threads_client_id before insert or update on public.communication_threads
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_communication_threads_lead_id before insert or update on public.communication_threads
for each row execute function app_private.guard_parent_organization('leads','lead_id');
create trigger tenant_communications_office_id before insert or update on public.communications
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_communications_thread_id before insert or update on public.communications
for each row execute function app_private.guard_parent_organization('communication_threads','thread_id');
create trigger tenant_communications_client_id before insert or update on public.communications
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_communications_lead_id before insert or update on public.communications
for each row execute function app_private.guard_parent_organization('leads','lead_id');
create trigger tenant_documents_office_id before insert or update on public.documents
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_documents_client_id before insert or update on public.documents
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_documents_enrollment_id before insert or update on public.documents
for each row execute function app_private.guard_parent_organization('enrollments','enrollment_id');
create trigger tenant_consent_records_client_id before insert or update on public.consent_records
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_consent_records_enrollment_id before insert or update on public.consent_records
for each row execute function app_private.guard_parent_organization('enrollments','enrollment_id');
create trigger tenant_consent_records_artifact_document_id before insert or update on public.consent_records
for each row execute function app_private.guard_parent_organization('documents','artifact_document_id');
create trigger tenant_tasks_office_id before insert or update on public.tasks
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_carrier_contracts_carrier_id before insert or update on public.carrier_contracts
for each row execute function app_private.guard_parent_organization('carriers','carrier_id');
create trigger tenant_commission_statements_carrier_id before insert or update on public.commission_statements
for each row execute function app_private.guard_parent_organization('carriers','carrier_id');
create trigger tenant_commission_lines_statement_id before insert or update on public.commission_lines
for each row execute function app_private.guard_parent_organization('commission_statements','statement_id');
create trigger tenant_commission_lines_client_id before insert or update on public.commission_lines
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_commission_lines_policy_id before insert or update on public.commission_lines
for each row execute function app_private.guard_parent_organization('policies','policy_id');
create trigger tenant_commission_exceptions_commission_line_id before insert or update on public.commission_exceptions
for each row execute function app_private.guard_parent_organization('commission_lines','commission_line_id');
create trigger tenant_provider_connections_office_id before insert or update on public.provider_connections
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_team_invitations_office_id before insert or update on public.team_invitations
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_automation_rules_office_id before insert or update on public.automation_rules
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_portal_invitations_client_id before insert or update on public.portal_invitations
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_client_providers_client_id before insert or update on public.client_providers
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_client_prescriptions_client_id before insert or update on public.client_prescriptions
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_client_pharmacies_client_id before insert or update on public.client_pharmacies
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_plan_comparisons_office_id before insert or update on public.plan_comparisons
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_plan_comparisons_client_id before insert or update on public.plan_comparisons
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_plan_comparisons_enrollment_id before insert or update on public.plan_comparisons
for each row execute function app_private.guard_parent_organization('enrollments','enrollment_id');
create trigger tenant_plan_comparison_items_comparison_id before insert or update on public.plan_comparison_items
for each row execute function app_private.guard_parent_organization('plan_comparisons','comparison_id');
create trigger tenant_plan_comparison_items_carrier_product_id before insert or update on public.plan_comparison_items
for each row execute function app_private.guard_parent_organization('carrier_products','carrier_product_id');
create trigger tenant_client_portal_accounts_client_id before insert or update on public.client_portal_accounts
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger tenant_communication_attachments_communication_id before insert or update on public.communication_attachments
for each row execute function app_private.guard_parent_organization('communications','communication_id');
create trigger tenant_communication_attachments_document_id before insert or update on public.communication_attachments
for each row execute function app_private.guard_parent_organization('documents','document_id');
create trigger tenant_appointment_types_office_id before insert or update on public.appointment_types
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_communication_templates_office_id before insert or update on public.communication_templates
for each row execute function app_private.guard_parent_organization('offices','office_id');
create trigger tenant_contact_preferences_client_id before insert or update on public.contact_preferences
for each row execute function app_private.guard_parent_organization('clients','client_id');
create trigger userorg_leads_assigned_user_id before insert or update on public.leads
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_clients_assigned_user_id before insert or update on public.clients
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_appointments_assigned_user_id before insert or update on public.appointments
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_enrollments_assigned_user_id before insert or update on public.enrollments
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_enrollment_evidence_created_by before insert or update on public.enrollment_evidence
for each row execute function app_private.guard_user_organization('created_by');
create trigger userorg_policy_events_created_by before insert or update on public.policy_events
for each row execute function app_private.guard_user_organization('created_by');
create trigger userorg_service_requests_assigned_user_id before insert or update on public.service_requests
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_tasks_assigned_user_id before insert or update on public.tasks
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_carrier_contracts_user_id before insert or update on public.carrier_contracts
for each row execute function app_private.guard_user_organization('user_id');
create trigger userorg_commission_lines_user_id before insert or update on public.commission_lines
for each row execute function app_private.guard_user_organization('user_id');
create trigger userorg_commission_exceptions_assigned_user_id before insert or update on public.commission_exceptions
for each row execute function app_private.guard_user_organization('assigned_user_id');
create trigger userorg_consent_records_captured_by before insert or update on public.consent_records
for each row execute function app_private.guard_user_organization('captured_by');
create trigger userorg_team_invitations_invited_by before insert or update on public.team_invitations
for each row execute function app_private.guard_user_organization('invited_by');
create trigger userorg_automation_rules_created_by before insert or update on public.automation_rules
for each row execute function app_private.guard_user_organization('created_by');
create trigger userorg_agent_licenses_user_id before insert or update on public.agent_licenses
for each row execute function app_private.guard_user_organization('user_id');
create trigger userorg_organization_settings_updated_by before insert or update on public.organization_settings
for each row execute function app_private.guard_user_organization('updated_by');
create trigger userorg_communication_templates_created_by before insert or update on public.communication_templates
for each row execute function app_private.guard_user_organization('created_by');
