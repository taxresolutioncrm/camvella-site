-- 065_last_admin_guard.sql
-- Prevents an agency from losing its final active administrator.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_last_active_agency_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  remaining_admins integer;
begin
  if old.role='agency_admin'
     and old.is_active=true
     and (
       new.role is distinct from old.role
       or new.is_active is distinct from old.is_active
       or new.organization_id is distinct from old.organization_id
     )
     and (
       new.role<>'agency_admin'
       or new.is_active=false
       or new.organization_id<>old.organization_id
     )
  then
    select count(*) into remaining_admins
    from public.memberships m
    where m.organization_id=old.organization_id
      and m.id<>old.id
      and m.role='agency_admin'
      and m.is_active=true;

    if remaining_admins<1 then
      raise exception 'cannot deactivate or demote the final active agency administrator';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_last_active_agency_admin()
from public, anon, authenticated;

create trigger memberships_last_active_admin_guard
before update of role,is_active,organization_id on public.memberships
for each row execute function app_private.guard_last_active_agency_admin();
