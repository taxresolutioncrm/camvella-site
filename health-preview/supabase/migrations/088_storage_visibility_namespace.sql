-- 088_storage_visibility_namespace.sql
-- Keeps agency and portal upload namespaces distinct inside client-document Storage.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.can_access_storage_object(
  p_bucket text,
  p_name text,
  p_write boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
  office_segment text;
  entity_id uuid;
  visibility text;
  entity_org uuid;
  entity_office uuid;
  expected_office text;
begin
  begin
    org_id:=split_part(p_name,'/',1)::uuid;
    office_segment:=split_part(p_name,'/',2);
    entity_id:=split_part(p_name,'/',3)::uuid;
    visibility:=split_part(p_name,'/',4);
  exception when others then
    return false;
  end;

  if p_bucket='client-documents' then
    select c.organization_id,c.office_id
    into entity_org,entity_office
    from public.clients c
    where c.id=entity_id;

    expected_office:=coalesce(entity_office::text,'shared');
    if entity_org is null
       or entity_org<>org_id
       or office_segment<>expected_office then
      return false;
    end if;

    if p_write then
      if visibility not in ('agency','shared') then
        return false;
      end if;

      return app_private.can_manage_client(entity_id)
        or app_private.has_org_role(
          org_id,
          array['compliance']::public.member_role[]
        );
    end if;

    return app_private.can_view_agency_sensitive_client(entity_id);
  end if;

  if p_bucket='enrollment-evidence' then
    select e.organization_id,e.office_id
    into entity_org,entity_office
    from public.enrollments e
    where e.id=entity_id;

    expected_office:=coalesce(entity_office::text,'shared');
    if entity_org is null
       or entity_org<>org_id
       or office_segment<>expected_office then
      return false;
    end if;

    if p_write then
      return exists(
        select 1
        from public.enrollments e
        where e.id=entity_id
          and (
            app_private.can_manage_client(e.client_id)
            or app_private.has_org_role(
              e.organization_id,
              array['compliance']::public.member_role[]
            )
          )
      );
    end if;

    return exists(
      select 1
      from public.enrollments e
      where e.id=entity_id
        and app_private.can_view_agency_sensitive_client(e.client_id)
    );
  end if;

  if p_bucket='communications' then
    select c.organization_id,c.office_id
    into entity_org,entity_office
    from public.communications c
    where c.id=entity_id;

    expected_office:=coalesce(entity_office::text,'shared');
    if entity_org is null
       or entity_org<>org_id
       or office_segment<>expected_office then
      return false;
    end if;

    if p_write then
      return exists(
        select 1
        from public.communications c
        where c.id=entity_id
          and (
            app_private.has_org_role(
              c.organization_id,
              array['agency_admin','manager']::public.member_role[]
            )
            or (
              c.user_id=(select auth.uid())
              and app_private.has_org_role(
                c.organization_id,
                array['agent']::public.member_role[]
              )
            )
          )
      );
    end if;

    return exists(
      select 1
      from public.communications c
      where c.id=entity_id
        and (
          (
            c.client_id is not null
            and app_private.can_view_agency_sensitive_client(c.client_id)
          )
          or app_private.has_org_role(
            c.organization_id,
            array['agency_admin','manager','compliance']::public.member_role[]
          )
          or (
            c.user_id=(select auth.uid())
            and app_private.has_org_role(
              c.organization_id,
              array['agent']::public.member_role[]
            )
          )
        )
    );
  end if;

  if p_bucket='commission-statements' then
    select cs.organization_id
    into entity_org
    from public.commission_statements cs
    where cs.id=entity_id;

    if entity_org is null
       or entity_org<>org_id
       or office_segment<>'shared'
       or not app_private.has_aal2() then
      return false;
    end if;

    return (
      (
        p_write
        and app_private.has_org_role(
          org_id,
          array['agency_admin','revenue']::public.member_role[]
        )
      )
      or (
        not p_write
        and app_private.has_org_role(
          org_id,
          array['agency_admin','manager','revenue']::public.member_role[]
        )
      )
    );
  end if;

  return false;
end;
$$;

revoke all on function app_private.can_access_storage_object(text,text,boolean)
from public, anon;
grant execute on function app_private.can_access_storage_object(text,text,boolean)
to authenticated;
