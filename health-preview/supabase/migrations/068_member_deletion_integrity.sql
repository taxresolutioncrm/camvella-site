-- 068_member_deletion_integrity.sql
-- Prevents removal of the final administrator and safely retires public endpoints when a member is deleted.
-- DO NOT APPLY until the dedicated Supabase project is selected.

-- A booking link cannot survive without its owning Auth user.
alter table public.booking_links
drop constraint if exists booking_links_user_id_fkey;

alter table public.booking_links
add constraint booking_links_user_id_fkey
foreign key (user_id)
references auth.users(id)
on delete cascade;

create or replace function app_private.prepare_member_removal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  remaining_admins integer;
begin
  perform pg_advisory_xact_lock(
    hashtext('member-removal:'||old.organization_id::text||':'||old.user_id::text)
  );

  if old.role='agency_admin' and old.is_active=true then
    perform pg_advisory_xact_lock(
      hashtext('last-admin:'||old.organization_id::text)
    );

    select count(*) into remaining_admins
    from public.memberships m
    where m.organization_id=old.organization_id
      and m.id<>old.id
      and m.role='agency_admin'
      and m.is_active=true;

    if remaining_admins<1 then
      raise exception 'cannot delete the final active agency administrator';
    end if;
  end if;

  update public.booking_links
  set is_active=false
  where organization_id=old.organization_id
    and user_id=old.user_id
    and is_active=true;

  update public.scheduling_availability_rules
  set is_active=false
  where organization_id=old.organization_id
    and user_id=old.user_id
    and is_active=true;

  update public.public_intake_forms
  set assigned_user_id=null
  where organization_id=old.organization_id
    and assigned_user_id=old.user_id;

  update public.communication_endpoints
  set status='disabled',
      inbound_enabled=false,
      outbound_enabled=false
  where organization_id=old.organization_id
    and user_id=old.user_id
    and status<>'disabled';

  return old;
end;
$$;

revoke all on function app_private.prepare_member_removal()
from public, anon, authenticated;

drop trigger if exists memberships_prepare_removal on public.memberships;
create trigger memberships_prepare_removal
before delete on public.memberships
for each row execute function app_private.prepare_member_removal();
