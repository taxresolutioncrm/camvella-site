-- 011_workflow_guards.sql
-- Database-level integrity guards for critical workflows.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.enrollment_evidence
add column required_for_submission boolean not null default true;

alter table public.policies
add constraint policies_date_order_chk
check (termination_date is null or termination_date >= effective_date);

alter table public.renewals
add constraint renewals_window_order_chk
check (review_window_end is null or review_window_start is null or review_window_end >= review_window_start);

alter table public.service_requests
add constraint service_requests_resolution_chk
check (resolved_at is null or resolved_at >= created_at);

alter table public.team_invitations
add constraint team_invitations_expiry_chk
check (expires_at > created_at);

create unique index team_invitations_active_email_ci_uq
on public.team_invitations(organization_id,lower(email))
where accepted_at is null;

create or replace function app_private.guard_last_admin()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  remaining integer;
  removing_admin boolean := false;
begin
  if tg_op = 'DELETE' then
    removing_admin := old.role='agency_admin' and old.is_active=true;
  elsif tg_op = 'UPDATE' then
    removing_admin := old.role='agency_admin' and old.is_active=true
      and (new.role <> 'agency_admin' or new.is_active=false or new.organization_id <> old.organization_id);
  end if;

  if removing_admin then
    select count(*) into remaining
    from public.memberships m
    where m.organization_id=old.organization_id
      and m.role='agency_admin'
      and m.is_active=true
      and m.id<>old.id;

    if remaining=0 then
      raise exception 'cannot remove or deactivate the final agency administrator';
    end if;
  end if;

  return case when tg_op='DELETE' then old else new end;
end;
$$;

revoke all on function app_private.guard_last_admin() from public, anon, authenticated;

create trigger memberships_guard_last_admin
before update or delete on public.memberships
for each row execute function app_private.guard_last_admin();

create or replace function app_private.guard_enrollment_submission()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  required_count integer;
  incomplete_count integer;
begin
  if new.lifecycle_status in ('submitted','pending','approved','active')
     and new.lifecycle_status is distinct from old.lifecycle_status then

    select count(*),
           count(*) filter (where lower(status) <> 'complete')
    into required_count,incomplete_count
    from public.enrollment_evidence ee
    where ee.enrollment_id=new.id
      and ee.required_for_submission=true;

    if required_count=0 then
      raise exception 'submission blocked: required evidence checklist is not initialized';
    end if;

    if incomplete_count>0 then
      raise exception 'submission blocked: required enrollment evidence is incomplete';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_enrollment_submission() from public, anon, authenticated;

create trigger enrollments_guard_submission
before update of lifecycle_status on public.enrollments
for each row execute function app_private.guard_enrollment_submission();
