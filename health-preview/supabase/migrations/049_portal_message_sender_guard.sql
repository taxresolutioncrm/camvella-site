-- 049_portal_message_sender_guard.sql
-- Allows portal users to author inbound portal messages without becoming agency members.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_portal_message_sender()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.sender_user_id is null then
    raise exception 'portal message sender is required';
  end if;

  if new.direction='inbound' then
    if not exists(
      select 1
      from public.client_portal_accounts p
      where p.organization_id=new.organization_id
        and p.client_id=new.client_id
        and p.user_id=new.sender_user_id
        and p.status='active'
    ) then
      raise exception 'inbound portal message sender is not an active portal user for this client';
    end if;
    return new;
  end if;

  if new.direction='outbound' then
    if not exists(
      select 1
      from public.memberships m
      where m.organization_id=new.organization_id
        and m.user_id=new.sender_user_id
        and m.is_active=true
    ) then
      raise exception 'outbound portal message sender is not an active agency member';
    end if;
    return new;
  end if;

  raise exception 'unsupported portal message direction';
end;
$$;

revoke all on function app_private.guard_portal_message_sender()
from public, anon, authenticated;

drop trigger if exists userorg_portal_messages_sender_user_id
on public.portal_messages;

create trigger portal_messages_sender_guard
before insert or update on public.portal_messages
for each row execute function app_private.guard_portal_message_sender();
