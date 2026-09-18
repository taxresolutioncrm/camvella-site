-- 037_assignment_office_alignment.sql
-- Current assignments must reference an active member and, for agents, the same office.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_active_assignment()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  user_column text := tg_argv[0];
  target_user uuid;
  target_office uuid;
  member_role public.member_role;
  member_office uuid;
begin
  begin
    target_user := nullif(to_jsonb(new)->>user_column,'')::uuid;
    target_office := nullif(to_jsonb(new)->>'office_id','')::uuid;
  exception when others then
    raise exception 'invalid assignment reference in %.%',tg_table_name,user_column;
  end;

  if target_user is null then
    return new;
  end if;

  select m.role,m.office_id
  into member_role,member_office
  from public.memberships m
  where m.organization_id=new.organization_id
    and m.user_id=target_user
    and m.is_active=true
  limit 1;

  if member_role is null then
    raise exception 'work assignment must reference an active member of the record organization';
  end if;

  if member_role='agent'
     and target_office is not null
     and member_office is distinct from target_office then
    raise exception 'agent assignment must match the record office';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_active_assignment() from public, anon, authenticated;

-- Replace active-user-only guards on office-scoped work records.
drop trigger if exists userorg_leads_assigned_user_id on public.leads;
create trigger userorg_leads_assigned_user_id
before insert or update on public.leads
for each row execute function app_private.guard_active_assignment('assigned_user_id');

drop trigger if exists userorg_clients_assigned_user_id on public.clients;
create trigger userorg_clients_assigned_user_id
before insert or update on public.clients
for each row execute function app_private.guard_active_assignment('assigned_user_id');

drop trigger if exists userorg_appointments_assigned_user_id on public.appointments;
create trigger userorg_appointments_assigned_user_id
before insert or update on public.appointments
for each row execute function app_private.guard_active_assignment('assigned_user_id');

drop trigger if exists userorg_enrollments_assigned_user_id on public.enrollments;
create trigger userorg_enrollments_assigned_user_id
before insert or update on public.enrollments
for each row execute function app_private.guard_active_assignment('assigned_user_id');

drop trigger if exists userorg_service_requests_assigned_user_id on public.service_requests;
create trigger userorg_service_requests_assigned_user_id
before insert or update on public.service_requests
for each row execute function app_private.guard_active_assignment('assigned_user_id');

drop trigger if exists userorg_communication_endpoints_user_id on public.communication_endpoints;
create trigger userorg_communication_endpoints_user_id
before insert or update on public.communication_endpoints
for each row execute function app_private.guard_active_assignment('user_id');

drop trigger if exists userorg_scheduling_availability_user_id on public.scheduling_availability_rules;
create trigger userorg_scheduling_availability_user_id
before insert or update on public.scheduling_availability_rules
for each row execute function app_private.guard_active_assignment('user_id');

drop trigger if exists userorg_booking_links_user_id on public.booking_links;
create trigger userorg_booking_links_user_id
before insert or update on public.booking_links
for each row execute function app_private.guard_active_assignment('user_id');

drop trigger if exists userorg_public_intake_forms_assigned_user_id on public.public_intake_forms;
create trigger userorg_public_intake_forms_assigned_user_id
before insert or update on public.public_intake_forms
for each row execute function app_private.guard_active_assignment('assigned_user_id');
