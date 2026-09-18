-- 063_member_deactivation_public_safety.sql
-- Prevents deactivated members from leaving public booking/intake/communication endpoints pointing at inactive users.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.prepare_member_deactivation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.is_active=true and new.is_active=false then
    -- Run while the membership is still active so active-assignment guards permit the cleanup.
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
        outbound_enabled=false
    where organization_id=old.organization_id
      and user_id=old.user_id
      and status='active';
  end if;

  return new;
end;
$$;

revoke all on function app_private.prepare_member_deactivation()
from public, anon, authenticated;

create trigger memberships_prepare_deactivation
before update of is_active on public.memberships
for each row
when (old.is_active is distinct from new.is_active)
execute function app_private.prepare_member_deactivation();
