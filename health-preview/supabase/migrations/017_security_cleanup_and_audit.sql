-- 017_security_cleanup_and_audit.sql
-- Final invitation, portal-storage, and audit hardening.
-- DO NOT APPLY until the dedicated Supabase project is selected.

-- Invitation tokens are created/accepted only through trusted server RPCs.
drop policy if exists team_invitations_write on public.team_invitations;
drop policy if exists portal_invitations_write on public.portal_invitations;
revoke insert,update,delete on public.team_invitations from authenticated;
revoke insert,update,delete on public.portal_invitations from authenticated;

-- Portal client-document Storage access.
-- Path convention for client-documents:
-- <organization_id>/<office-or-shared>/<client_id>/<filename>
create or replace function app_private.portal_can_access_storage_object(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
  client_id_value uuid;
begin
  begin
    org_id := split_part(object_name,'/',1)::uuid;
    client_id_value := split_part(object_name,'/',3)::uuid;
  exception when others then
    return false;
  end;

  return exists (
    select 1 from public.client_portal_accounts p
    where p.user_id=(select auth.uid())
      and p.organization_id=org_id
      and p.client_id=client_id_value
      and p.status='active'
  );
end;
$$;

revoke all on function app_private.portal_can_access_storage_object(text) from public, anon;
grant execute on function app_private.portal_can_access_storage_object(text) to authenticated;

create policy "storage_select_portal_client_documents"
on storage.objects
for select to authenticated
using (
  bucket_id='client-documents'
  and app_private.portal_can_access_storage_object(name)
);

create policy "storage_insert_portal_client_documents"
on storage.objects
for insert to authenticated
with check (
  bucket_id='client-documents'
  and app_private.portal_can_access_storage_object(name)
);

-- Expand trusted audit coverage for sensitive workflow changes.
create trigger audit_appointments after insert or update or delete on public.appointments
for each row execute function app_private.audit_row_change();
create trigger audit_documents after insert or update or delete on public.documents
for each row execute function app_private.audit_row_change();
create trigger audit_communications after insert or update or delete on public.communications
for each row execute function app_private.audit_row_change();
create trigger audit_tasks after insert or update or delete on public.tasks
for each row execute function app_private.audit_row_change();
create trigger audit_renewals after insert or update or delete on public.renewals
for each row execute function app_private.audit_row_change();
create trigger audit_agent_licenses after insert or update or delete on public.agent_licenses
for each row execute function app_private.audit_row_change();
create trigger audit_client_providers after insert or update or delete on public.client_providers
for each row execute function app_private.audit_row_change();
create trigger audit_client_prescriptions after insert or update or delete on public.client_prescriptions
for each row execute function app_private.audit_row_change();
create trigger audit_client_pharmacies after insert or update or delete on public.client_pharmacies
for each row execute function app_private.audit_row_change();
create trigger audit_plan_comparisons after insert or update or delete on public.plan_comparisons
for each row execute function app_private.audit_row_change();
create trigger audit_organization_settings after insert or update or delete on public.organization_settings
for each row execute function app_private.audit_row_change();
create trigger audit_appointment_types after insert or update or delete on public.appointment_types
for each row execute function app_private.audit_row_change();
create trigger audit_communication_templates after insert or update or delete on public.communication_templates
for each row execute function app_private.audit_row_change();
create trigger audit_contact_preferences after insert or update or delete on public.contact_preferences
for each row execute function app_private.audit_row_change();
