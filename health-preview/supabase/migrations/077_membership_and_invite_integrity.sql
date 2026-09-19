-- 077_membership_and_invite_integrity.sql
-- Freezes membership identity fields and removes the obsolete invite-history blocker.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_membership_identity_immutable()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'membership user_id is immutable';
  end if;

  if new.organization_id is distinct from old.organization_id then
    raise exception 'membership organization_id is immutable';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_membership_identity_immutable()
from public, anon, authenticated;

drop trigger if exists memberships_identity_immutable on public.memberships;
create trigger memberships_identity_immutable
before update of user_id,organization_id on public.memberships
for each row execute function app_private.guard_membership_identity_immutable();

-- The original table-level unique constraint prevented preserving accepted
-- invitation history for an email that is later invited again. Active invites
-- are already protected by team_invitations_active_email_uq.
alter table public.team_invitations
drop constraint if exists team_invitations_organization_id_email_key;
