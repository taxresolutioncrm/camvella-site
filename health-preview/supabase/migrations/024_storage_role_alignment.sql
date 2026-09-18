-- 024_storage_role_alignment.sql
-- Aligns private Storage access with CRM role/assignment boundaries.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists "storage_select_org" on storage.objects;
drop policy if exists "storage_insert_org" on storage.objects;
drop policy if exists "storage_update_org" on storage.objects;
drop policy if exists "storage_delete_org" on storage.objects;

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
  entity_id uuid;
begin
  begin
    org_id := split_part(p_name,'/',1)::uuid;
    entity_id := split_part(p_name,'/',3)::uuid;
  exception when others then
    return false;
  end;

  if p_bucket='client-documents' then
    if p_write then
      return app_private.can_manage_client(entity_id)
        or app_private.has_org_role(org_id,array['compliance']::public.member_role[]);
    end if;
    return app_private.can_view_sensitive_client(entity_id);
  end if;

  if p_bucket='enrollment-evidence' then
    if p_write then
      return exists(
        select 1 from public.enrollments e
        where e.id=entity_id
          and (
            app_private.can_manage_client(e.client_id)
            or app_private.has_org_role(e.organization_id,array['compliance']::public.member_role[])
          )
      );
    end if;
    return exists(
      select 1 from public.enrollments e
      where e.id=entity_id
        and app_private.can_view_client(e.client_id)
    );
  end if;

  if p_bucket='communications' then
    if p_write then
      return exists(
        select 1 from public.communications c
        where c.id=entity_id
          and (
            app_private.has_org_role(c.organization_id,array['agency_admin','manager']::public.member_role[])
            or (
              c.user_id=(select auth.uid())
              and app_private.has_org_role(c.organization_id,array['agent']::public.member_role[])
            )
          )
      );
    end if;
    return exists(
      select 1 from public.communications c
      where c.id=entity_id
        and (
          (c.client_id is not null and app_private.can_view_sensitive_client(c.client_id))
          or app_private.has_org_role(c.organization_id,array['agency_admin','manager','compliance']::public.member_role[])
        )
    );
  end if;

  if p_bucket='commission-statements' then
    return exists(
      select 1 from public.commission_statements cs
      where cs.id=entity_id
        and cs.organization_id=org_id
        and (
          (p_write and app_private.has_org_role(org_id,array['agency_admin','revenue']::public.member_role[]))
          or ((not p_write) and app_private.has_org_role(org_id,array['agency_admin','manager','revenue']::public.member_role[]))
        )
    );
  end if;

  return false;
end;
$$;

revoke all on function app_private.can_access_storage_object(text,text,boolean) from public, anon;
grant execute on function app_private.can_access_storage_object(text,text,boolean) to authenticated;

create policy "storage_select_role_scoped"
on storage.objects
for select to authenticated
using (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and app_private.can_access_storage_object(bucket_id,name,false)
);

create policy "storage_insert_role_scoped"
on storage.objects
for insert to authenticated
with check (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and app_private.can_access_storage_object(bucket_id,name,true)
);

create policy "storage_update_role_scoped"
on storage.objects
for update to authenticated
using (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and app_private.can_access_storage_object(bucket_id,name,true)
)
with check (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and app_private.can_access_storage_object(bucket_id,name,true)
);

create policy "storage_delete_role_scoped"
on storage.objects
for delete to authenticated
using (
  bucket_id in ('client-documents','enrollment-evidence','communications','commission-statements')
  and app_private.can_access_storage_object(bucket_id,name,true)
);

-- Portal clients retain scoped read/upload for their own client-documents path.
-- The portal policies from migration 017 remain additive.
