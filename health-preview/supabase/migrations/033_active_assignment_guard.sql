-- 033_active_assignment_guard.sql
-- Separates historical actor references from active work assignments.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_active_user_organization()
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
      and m.is_active=true
  ) then
    raise exception 'work assignment must reference an active member of the record organization';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_active_user_organization() from public, anon, authenticated;

drop trigger if exists userorg_leads_assigned_user_id on public.leads;
create trigger userorg_leads_assigned_user_id
before insert or update on public.leads
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_clients_assigned_user_id on public.clients;
create trigger userorg_clients_assigned_user_id
before insert or update on public.clients
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_appointments_assigned_user_id on public.appointments;
create trigger userorg_appointments_assigned_user_id
before insert or update on public.appointments
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_enrollments_assigned_user_id on public.enrollments;
create trigger userorg_enrollments_assigned_user_id
before insert or update on public.enrollments
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_service_requests_assigned_user_id on public.service_requests;
create trigger userorg_service_requests_assigned_user_id
before insert or update on public.service_requests
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_tasks_assigned_user_id on public.tasks;
create trigger userorg_tasks_assigned_user_id
before insert or update on public.tasks
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_commission_exceptions_assigned_user_id on public.commission_exceptions;
create trigger userorg_commission_exceptions_assigned_user_id
before insert or update on public.commission_exceptions
for each row execute function app_private.guard_active_user_organization('assigned_user_id');

drop trigger if exists userorg_communication_endpoints_user_id on public.communication_endpoints;
create trigger userorg_communication_endpoints_user_id
before insert or update on public.communication_endpoints
for each row execute function app_private.guard_active_user_organization('user_id');

drop trigger if exists userorg_scheduling_availability_user_id on public.scheduling_availability_rules;
create trigger userorg_scheduling_availability_user_id
before insert or update on public.scheduling_availability_rules
for each row execute function app_private.guard_active_user_organization('user_id');

drop trigger if exists userorg_booking_links_user_id on public.booking_links;
create trigger userorg_booking_links_user_id
before insert or update on public.booking_links
for each row execute function app_private.guard_active_user_organization('user_id');

drop trigger if exists userorg_public_intake_forms_assigned_user_id on public.public_intake_forms;
create trigger userorg_public_intake_forms_assigned_user_id
before insert or update on public.public_intake_forms
for each row execute function app_private.guard_active_user_organization('assigned_user_id');
