-- 070_storage_office_alignment.sql
-- Storage paths must carry the same office segment as their database/client context.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_document_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_office text;
  path_client uuid;
  visibility text;
  expected_office text;
begin
  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_office:=split_part(new.storage_path,'/',2);
    path_client:=split_part(new.storage_path,'/',3)::uuid;
    visibility:=split_part(new.storage_path,'/',4);
  exception when others then
    raise exception 'invalid client document storage path';
  end;

  expected_office:=coalesce(new.office_id::text,'shared');

  if path_org<>new.organization_id
     or path_client is distinct from new.client_id
     or path_office<>expected_office then
    raise exception 'client document storage path does not match organization/office/client';
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

create or replace function app_private.guard_enrollment_evidence_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_office text;
  path_enrollment uuid;
  enrollment_office uuid;
  expected_office text;
begin
  if new.storage_path is null then
    return new;
  end if;

  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_office:=split_part(new.storage_path,'/',2);
    path_enrollment:=split_part(new.storage_path,'/',3)::uuid;
  exception when others then
    raise exception 'invalid enrollment evidence storage path';
  end;

  select e.office_id into enrollment_office
  from public.enrollments e
  where e.id=new.enrollment_id
    and e.organization_id=new.organization_id;

  expected_office:=coalesce(enrollment_office::text,'shared');

  if path_org<>new.organization_id
     or path_enrollment<>new.enrollment_id
     or path_office<>expected_office then
    raise exception 'enrollment evidence path does not match organization/office/enrollment';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_enrollment_evidence_storage_path()
from public, anon, authenticated;

create or replace function app_private.guard_import_job_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_office text;
  path_type text;
  expected_office text;
begin
  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_office:=split_part(new.storage_path,'/',2);
    path_type:=split_part(new.storage_path,'/',3);
  exception when others then
    raise exception 'invalid import storage path';
  end;

  expected_office:=coalesce(new.office_id::text,'shared');

  if path_org<>new.organization_id
     or path_office<>expected_office
     or path_type<>new.import_type then
    raise exception 'import path does not match organization/office/import type';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_import_job_storage_path()
from public, anon, authenticated;

create or replace function app_private.portal_can_read_storage_object(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
  office_segment text;
  client_id_value uuid;
  visibility text;
  expected_office text;
  portal_allowed boolean;
begin
  begin
    org_id:=split_part(object_name,'/',1)::uuid;
    office_segment:=split_part(object_name,'/',2);
    client_id_value:=split_part(object_name,'/',3)::uuid;
    visibility:=split_part(object_name,'/',4);
  exception when others then
    return false;
  end;

  if visibility not in ('portal','shared') then
    return false;
  end if;

  select
    exists(
      select 1
      from public.client_portal_accounts p
      where p.user_id=(select auth.uid())
        and p.organization_id=org_id
        and p.client_id=client_id_value
        and p.status='active'
    ),
    coalesce(c.office_id::text,'shared')
  into portal_allowed,expected_office
  from public.clients c
  where c.id=client_id_value
    and c.organization_id=org_id;

  if not coalesce(portal_allowed,false)
     or office_segment is distinct from expected_office then
    return false;
  end if;

  if visibility='portal' then
    return true;
  end if;

  return exists(
    select 1
    from public.documents d
    where d.organization_id=org_id
      and d.office_id is not distinct from (
        case when expected_office='shared' then null else expected_office::uuid end
      )
      and d.client_id=client_id_value
      and d.storage_path=object_name
      and d.portal_visible=true
  );
end;
$$;

create or replace function app_private.portal_can_upload_storage_object(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
  office_segment text;
  client_id_value uuid;
  visibility text;
  expected_office text;
begin
  begin
    org_id:=split_part(object_name,'/',1)::uuid;
    office_segment:=split_part(object_name,'/',2);
    client_id_value:=split_part(object_name,'/',3)::uuid;
    visibility:=split_part(object_name,'/',4);
  exception when others then
    return false;
  end;

  if visibility<>'portal' then
    return false;
  end if;

  select coalesce(c.office_id::text,'shared')
  into expected_office
  from public.clients c
  where c.id=client_id_value
    and c.organization_id=org_id;

  if expected_office is null or office_segment<>expected_office then
    return false;
  end if;

  return exists(
    select 1
    from public.client_portal_accounts p
    where p.user_id=(select auth.uid())
      and p.organization_id=org_id
      and p.client_id=client_id_value
      and p.status='active'
  );
end;
$$;

revoke all on function app_private.portal_can_read_storage_object(text)
from public, anon;
revoke all on function app_private.portal_can_upload_storage_object(text)
from public, anon;
grant execute on function app_private.portal_can_read_storage_object(text)
to authenticated;
grant execute on function app_private.portal_can_upload_storage_object(text)
to authenticated;
