-- 086_append_only_operational_history.sql
-- Prevents browser-side hard deletion of operational/compliance history and limits
-- Storage deletes to uncommitted uploads that need rollback cleanup.
-- DO NOT APPLY until the dedicated Supabase project is selected.

revoke delete on
  public.enrollments,
  public.enrollment_evidence,
  public.policies,
  public.policy_events,
  public.service_requests,
  public.renewals,
  public.communication_threads,
  public.communications,
  public.documents,
  public.consent_records,
  public.carrier_contracts,
  public.commission_statements,
  public.commission_lines,
  public.commission_exceptions,
  public.audit_log,
  public.provider_event_ledger,
  public.automation_runs,
  public.integration_sync_jobs,
  public.portal_messages,
  public.import_jobs,
  public.evidence_bundles,
  public.outreach_campaigns,
  public.outreach_campaign_members,
  public.agent_licenses,
  public.client_portal_accounts,
  public.team_invitations,
  public.portal_invitations
from authenticated;

create or replace function app_private.can_cleanup_storage_object(
  p_bucket text,
  p_name text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  entity_id uuid;
  visibility text;
begin
  if not app_private.can_access_storage_object(p_bucket,p_name,true) then
    return false;
  end if;

  begin
    entity_id:=split_part(p_name,'/',3)::uuid;
    visibility:=split_part(p_name,'/',4);
  exception when others then
    return false;
  end;

  if p_bucket='client-documents' then
    if visibility<>'agency' then
      return false;
    end if;

    return not exists(
      select 1
      from public.documents d
      where d.storage_path=p_name
    );
  end if;

  if p_bucket='enrollment-evidence' then
    return not exists(
      select 1
      from public.enrollment_evidence e
      where e.storage_path=p_name
    );
  end if;

  if p_bucket='commission-statements' then
    return exists(
      select 1
      from public.commission_statements cs
      where cs.id=entity_id
        and cs.storage_path is distinct from p_name
    );
  end if;

  return false;
end;
$$;

revoke all on function app_private.can_cleanup_storage_object(text,text)
from public, anon;
grant execute on function app_private.can_cleanup_storage_object(text,text)
to authenticated;

create or replace function app_private.can_cleanup_import_object(
  p_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    app_private.can_access_import_object(p_name,true)
    and not exists(
      select 1
      from public.import_jobs j
      where j.storage_path=p_name
    )
$$;

revoke all on function app_private.can_cleanup_import_object(text)
from public, anon;
grant execute on function app_private.can_cleanup_import_object(text)
to authenticated;

drop policy if exists "storage_delete_role_scoped" on storage.objects;
create policy "storage_delete_agency_orphan_cleanup"
on storage.objects
for delete to authenticated
using (
  bucket_id in (
    'client-documents',
    'enrollment-evidence',
    'commission-statements'
  )
  and app_private.can_cleanup_storage_object(bucket_id,name)
);

drop policy if exists "imports_delete_role_scoped" on storage.objects;
create policy "imports_delete_orphan_cleanup"
on storage.objects
for delete to authenticated
using (
  bucket_id='imports'
  and app_private.can_cleanup_import_object(name)
);
