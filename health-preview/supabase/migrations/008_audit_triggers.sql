-- 008_audit_triggers.sql
-- Trusted append-only audit capture for core mutations.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, auth, app_private
as $$
declare
  row_org uuid;
  row_id uuid;
  actor uuid;
  before_row jsonb;
  after_row jsonb;
begin
  actor := auth.uid();

  if tg_op = 'INSERT' then
    after_row := to_jsonb(new);
    row_org := nullif(after_row->>'organization_id','')::uuid;
    row_id := nullif(after_row->>'id','')::uuid;
  elsif tg_op = 'UPDATE' then
    before_row := to_jsonb(old);
    after_row := to_jsonb(new);
    row_org := coalesce(
      nullif(after_row->>'organization_id','')::uuid,
      nullif(before_row->>'organization_id','')::uuid
    );
    row_id := coalesce(
      nullif(after_row->>'id','')::uuid,
      nullif(before_row->>'id','')::uuid
    );
  else
    before_row := to_jsonb(old);
    row_org := nullif(before_row->>'organization_id','')::uuid;
    row_id := nullif(before_row->>'id','')::uuid;
  end if;

  if row_org is not null then
    insert into public.audit_log(
      organization_id,
      actor_user_id,
      actor_type,
      action,
      entity_type,
      entity_id,
      before_json,
      after_json,
      metadata_json
    ) values (
      row_org,
      actor,
      case when actor is null then 'system' else 'user' end,
      lower(tg_table_name)||'.'||lower(tg_op),
      tg_table_name,
      row_id,
      before_row,
      after_row,
      jsonb_build_object('trigger',tg_name)
    );
  end if;

  return case when tg_op='DELETE' then old else new end;
end;
$$;

revoke all on function app_private.audit_row_change() from public, anon, authenticated;

create trigger audit_leads after insert or update or delete on public.leads
for each row execute function app_private.audit_row_change();
create trigger audit_clients after insert or update or delete on public.clients
for each row execute function app_private.audit_row_change();
create trigger audit_memberships after insert or update or delete on public.memberships
for each row execute function app_private.audit_row_change();
create trigger audit_enrollments after insert or update or delete on public.enrollments
for each row execute function app_private.audit_row_change();
create trigger audit_evidence after insert or update or delete on public.enrollment_evidence
for each row execute function app_private.audit_row_change();
create trigger audit_policies after insert or update or delete on public.policies
for each row execute function app_private.audit_row_change();
create trigger audit_service_requests after insert or update or delete on public.service_requests
for each row execute function app_private.audit_row_change();
create trigger audit_consent after insert or update or delete on public.consent_records
for each row execute function app_private.audit_row_change();
create trigger audit_carrier_contracts after insert or update or delete on public.carrier_contracts
for each row execute function app_private.audit_row_change();
create trigger audit_commission_statements after insert or update or delete on public.commission_statements
for each row execute function app_private.audit_row_change();
create trigger audit_commission_exceptions after insert or update or delete on public.commission_exceptions
for each row execute function app_private.audit_row_change();
create trigger audit_provider_connections after insert or update or delete on public.provider_connections
for each row execute function app_private.audit_row_change();
create trigger audit_automation_rules after insert or update or delete on public.automation_rules
for each row execute function app_private.audit_row_change();
