-- 051_portal_message_read_receipts.sql
-- Portal users may mark agency messages read, but cannot edit agency message content.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists portal_messages_update on public.portal_messages;
revoke update on public.portal_messages from authenticated;
grant select,insert on public.portal_messages to authenticated;

create or replace function public.mark_my_portal_messages_read(
  p_message_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  updated_count integer;
begin
  if p_message_ids is null or coalesce(array_length(p_message_ids,1),0)=0 then
    return 0;
  end if;

  update public.portal_messages pm
  set read_at=coalesce(pm.read_at,now())
  where pm.id=any(p_message_ids)
    and pm.direction='outbound'
    and exists(
      select 1
      from public.client_portal_accounts p
      where p.user_id=(select auth.uid())
        and p.status='active'
        and p.organization_id=pm.organization_id
        and p.client_id=pm.client_id
    );

  get diagnostics updated_count=row_count;
  return updated_count;
end;
$$;

revoke all on function public.mark_my_portal_messages_read(uuid[])
from public, anon;
grant execute on function public.mark_my_portal_messages_read(uuid[])
to authenticated;
