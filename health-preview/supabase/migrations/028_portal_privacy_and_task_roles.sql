-- 028_portal_privacy_and_task_roles.sql
-- Separates client-portal visibility from internal agency evidence/comms and tightens task/automation roles.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.can_view_agency_sensitive_client(target_client uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists(
    select 1
    from public.clients c
    join public.memberships m on m.organization_id=c.organization_id
    where c.id=target_client
      and m.user_id=(select auth.uid())
      and m.is_active=true
      and (
        m.role in ('agency_admin','manager','compliance')
        or (
          m.role='agent'
          and c.assigned_user_id=(select auth.uid())
          and (c.office_id is null or m.office_id=c.office_id)
        )
      )
  )
$$;

revoke all on function app_private.can_view_agency_sensitive_client(uuid) from public, anon;
grant execute on function app_private.can_view_agency_sensitive_client(uuid) to authenticated;

-- Internal enrollment evidence is agency-only.
drop policy if exists enrollment_evidence_select on public.enrollment_evidence;
create policy enrollment_evidence_select on public.enrollment_evidence
for select to authenticated
using (
  exists(
    select 1 from public.enrollments e
    where e.id=enrollment_id
      and app_private.can_view_agency_sensitive_client(e.client_id)
  )
);

-- Internal communication history is never exposed to client-portal users.
drop policy if exists communication_threads_select on public.communication_threads;
create policy communication_threads_select on public.communication_threads
for select to authenticated
using (
  (client_id is not null and app_private.can_view_agency_sensitive_client(client_id))
  or (
    client_id is null
    and (
      app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
      or (
        assigned_user_id=(select auth.uid())
        and app_private.has_org_role(organization_id,array['agent']::public.member_role[])
      )
    )
  )
);

drop policy if exists communications_select on public.communications;
create policy communications_select on public.communications
for select to authenticated
using (
  (client_id is not null and app_private.can_view_agency_sensitive_client(client_id))
  or (
    client_id is null
    and (
      app_private.has_org_role(organization_id,array['agency_admin','manager','compliance']::public.member_role[])
      or (
        user_id=(select auth.uid())
        and app_private.has_org_role(organization_id,array['agent']::public.member_role[])
      )
    )
  )
);

drop policy if exists communication_attachments_select on public.communication_attachments;
create policy communication_attachments_select on public.communication_attachments
for select to authenticated
using (
  exists(
    select 1
    from public.communications c
    where c.id=communication_id
      and (
        (c.client_id is not null and app_private.can_view_agency_sensitive_client(c.client_id))
        or app_private.has_org_role(c.organization_id,array['agency_admin','manager','compliance']::public.member_role[])
        or (
          c.user_id=(select auth.uid())
          and app_private.has_org_role(c.organization_id,array['agent']::public.member_role[])
        )
      )
  )
);

-- Tasks are scoped to managers/admins or the user directly involved.
drop policy if exists tasks_all on public.tasks;
create policy tasks_select on public.tasks
for select to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or assigned_user_id=(select auth.uid())
  or created_by=(select auth.uid())
);

create policy tasks_insert on public.tasks
for insert to authenticated
with check (
  organization_id in (select app_private.current_org_ids())
  and (
    app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
    or assigned_user_id=(select auth.uid())
  )
);

create policy tasks_update on public.tasks
for update to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or assigned_user_id=(select auth.uid())
)
with check (
  organization_id in (select app_private.current_org_ids())
  and (
    app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
    or assigned_user_id=(select auth.uid())
  )
);

create policy tasks_delete on public.tasks
for delete to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or created_by=(select auth.uid())
);

-- Automation configuration/runtime is management-only.
drop policy if exists automation_rules_select on public.automation_rules;
create policy automation_rules_select on public.automation_rules
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

drop policy if exists automation_runs_select on public.automation_runs;
create policy automation_runs_select on public.automation_runs
for select to authenticated
using (
  organization_id in (select app_private.current_org_ids())
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

-- Portal invitations are visible only to management or the assigned agent's client.
drop policy if exists portal_invitations_select on public.portal_invitations;
create policy portal_invitations_select on public.portal_invitations
for select to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or exists(
    select 1 from public.clients c
    where c.id=client_id
      and app_private.can_manage_client(c.id)
  )
);

-- Replace storage helper so portal status never grants internal comm/evidence access.
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
        and app_private.can_view_agency_sensitive_client(e.client_id)
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
          (c.client_id is not null and app_private.can_view_agency_sensitive_client(c.client_id))
          or app_private.has_org_role(c.organization_id,array['agency_admin','manager','compliance']::public.member_role[])
          or (
            c.user_id=(select auth.uid())
            and app_private.has_org_role(c.organization_id,array['agent']::public.member_role[])
          )
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
