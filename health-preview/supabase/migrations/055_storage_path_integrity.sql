-- 055_storage_path_integrity.sql
-- Verifies private Storage object paths match the database records that reference them.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_document_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_client uuid;
  visibility text;
begin
  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_client:=split_part(new.storage_path,'/',3)::uuid;
    visibility:=split_part(new.storage_path,'/',4);
  exception when others then
    raise exception 'invalid client document storage path';
  end;

  if path_org<>new.organization_id or path_client is distinct from new.client_id then
    raise exception 'client document storage path does not match organization/client';
  end if;

  if new.portal_visible and visibility not in ('portal','shared') then
    raise exception 'portal-visible document must use portal/shared storage path';
  end if;

  if not new.portal_visible and visibility='portal' then
    raise exception 'portal upload metadata must remain portal-visible';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_document_storage_path()
from public, anon, authenticated;

drop trigger if exists document_storage_path_guard on public.documents;
create trigger document_storage_path_guard
before insert or update of organization_id,client_id,storage_path,portal_visible
on public.documents
for each row execute function app_private.guard_document_storage_path();

create or replace function app_private.guard_enrollment_evidence_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_enrollment uuid;
begin
  if new.storage_path is null then
    return new;
  end if;

  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_enrollment:=split_part(new.storage_path,'/',3)::uuid;
  exception when others then
    raise exception 'invalid enrollment evidence storage path';
  end;

  if path_org<>new.organization_id or path_enrollment<>new.enrollment_id then
    raise exception 'enrollment evidence storage path does not match record';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_enrollment_evidence_storage_path()
from public, anon, authenticated;

drop trigger if exists enrollment_evidence_storage_path_guard on public.enrollment_evidence;
create trigger enrollment_evidence_storage_path_guard
before insert or update of organization_id,enrollment_id,storage_path
on public.enrollment_evidence
for each row execute function app_private.guard_enrollment_evidence_storage_path();

create or replace function app_private.guard_commission_statement_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_carrier uuid;
begin
  if new.storage_path is null then
    return new;
  end if;

  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_carrier:=split_part(new.storage_path,'/',3)::uuid;
  exception when others then
    raise exception 'invalid commission statement storage path';
  end;

  if path_org<>new.organization_id or path_carrier<>new.carrier_id then
    raise exception 'commission statement storage path does not match organization/carrier';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_commission_statement_storage_path()
from public, anon, authenticated;

drop trigger if exists commission_statement_storage_path_guard on public.commission_statements;
create trigger commission_statement_storage_path_guard
before insert or update of organization_id,carrier_id,storage_path
on public.commission_statements
for each row execute function app_private.guard_commission_statement_storage_path();

create or replace function app_private.guard_import_job_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_type text;
begin
  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_type:=split_part(new.storage_path,'/',3);
  exception when others then
    raise exception 'invalid import storage path';
  end;

  if path_org<>new.organization_id or path_type<>new.import_type then
    raise exception 'import storage path does not match organization/import type';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_import_job_storage_path()
from public, anon, authenticated;

drop trigger if exists import_job_storage_path_guard on public.import_jobs;
create trigger import_job_storage_path_guard
before insert or update of organization_id,import_type,storage_path
on public.import_jobs
for each row execute function app_private.guard_import_job_storage_path();
