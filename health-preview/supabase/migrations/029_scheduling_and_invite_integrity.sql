-- 029_scheduling_and_invite_integrity.sql
-- Global appointment conflict guard + portal-invite uniqueness.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create unique index portal_invitations_active_client_email_uq
on public.portal_invitations(organization_id,client_id,lower(email))
where accepted_at is null;

alter table public.booking_links
alter column user_id set not null;

create or replace function app_private.guard_appointment_overlap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate_end timestamptz;
begin
  if new.assigned_user_id is null or new.status in ('cancelled','no_show') then
    return new;
  end if;

  candidate_end:=new.starts_at+make_interval(mins=>new.duration_minutes);

  perform pg_advisory_xact_lock(hashtext(new.assigned_user_id::text));

  if exists(
    select 1
    from public.appointments a
    where a.assigned_user_id=new.assigned_user_id
      and a.id is distinct from new.id
      and a.status not in ('cancelled','no_show')
      and tstzrange(a.starts_at,a.starts_at+make_interval(mins=>a.duration_minutes),'[)')
          && tstzrange(new.starts_at,candidate_end,'[)')
  ) then
    raise exception 'appointment conflicts with an existing appointment for the assigned user';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_appointment_overlap() from public, anon, authenticated;

create trigger appointment_overlap_guard
before insert or update of assigned_user_id,starts_at,duration_minutes,status
on public.appointments
for each row execute function app_private.guard_appointment_overlap();

alter table public.communications
add constraint communications_attachment_count_chk
check (attachment_count >= 0);

alter table public.communications
add constraint communications_fax_pages_chk
check (fax_pages is null or fax_pages > 0);

alter table public.communications
add constraint communications_voicemail_duration_chk
check (voicemail_duration_seconds is null or voicemail_duration_seconds >= 0);

alter table public.commission_statements
add constraint commission_statements_row_count_chk
check (row_count >= 0);
