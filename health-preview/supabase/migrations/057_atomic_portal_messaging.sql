-- 057_atomic_portal_messaging.sql
-- Makes client-visible portal messages and internal agency communication history atomic.
-- DO NOT APPLY until the dedicated Supabase project is selected.

revoke insert on public.portal_messages from authenticated;

create or replace function public.record_portal_message(
  p_actor_user_id uuid,
  p_client_id uuid,
  p_direction public.communication_direction,
  p_subject text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  c public.clients%rowtype;
  portal_message_id uuid;
  thread_id uuid;
  communication_id uuid;
  now_at timestamptz:=now();
begin
  if p_direction not in ('inbound','outbound') then
    raise exception 'portal message direction must be inbound or outbound';
  end if;

  if length(trim(coalesce(p_body,'')))<1 then
    raise exception 'portal message body is required';
  end if;

  select * into c
  from public.clients
  where id=p_client_id;

  if c.id is null then
    raise exception 'client not found';
  end if;

  if p_direction='inbound' then
    if not exists(
      select 1
      from public.client_portal_accounts p
      where p.organization_id=c.organization_id
        and p.client_id=c.id
        and p.user_id=p_actor_user_id
        and p.status='active'
    ) then
      raise exception 'portal sender is not authorized for this client';
    end if;
  else
    if not exists(
      select 1
      from public.memberships m
      where m.organization_id=c.organization_id
        and m.user_id=p_actor_user_id
        and m.is_active=true
        and (
          m.role in ('agency_admin','manager')
          or (
            m.role='agent'
            and c.assigned_user_id=p_actor_user_id
            and (c.office_id is null or m.office_id=c.office_id)
          )
        )
    ) then
      raise exception 'agency sender cannot message this client';
    end if;
  end if;

  insert into public.portal_messages(
    organization_id,
    office_id,
    client_id,
    direction,
    subject,
    body_text,
    sender_user_id,
    created_at
  ) values (
    c.organization_id,
    c.office_id,
    c.id,
    p_direction,
    nullif(trim(p_subject),''),
    trim(p_body),
    p_actor_user_id,
    now_at
  )
  returning id into portal_message_id;

  insert into public.communication_threads(
    organization_id,
    office_id,
    client_id,
    subject,
    last_channel,
    last_message_at,
    assigned_user_id,
    status,
    created_at
  ) values (
    c.organization_id,
    c.office_id,
    c.id,
    coalesce(nullif(trim(p_subject),''),'Portal message'),
    'portal',
    now_at,
    c.assigned_user_id,
    'open',
    now_at
  )
  returning id into thread_id;

  insert into public.communications(
    organization_id,
    office_id,
    thread_id,
    channel,
    direction,
    client_id,
    user_id,
    provider,
    provider_status,
    from_address,
    to_address,
    subject,
    body_text,
    body_preview,
    created_at
  ) values (
    c.organization_id,
    c.office_id,
    thread_id,
    'portal',
    p_direction,
    c.id,
    case when p_direction='outbound' then p_actor_user_id else null end,
    'client_portal',
    case when p_direction='outbound' then 'delivered' else 'received' end,
    case when p_direction='outbound' then 'agency_portal' else c.id::text end,
    case when p_direction='outbound' then c.id::text else 'agency_portal' end,
    nullif(trim(p_subject),''),
    trim(p_body),
    left(trim(p_body),240),
    now_at
  )
  returning id into communication_id;

  return jsonb_build_object(
    'portal_message_id',portal_message_id,
    'thread_id',thread_id,
    'communication_id',communication_id,
    'direction',p_direction,
    'created_at',now_at
  );
end;
$$;

revoke all on function public.record_portal_message(uuid,uuid,public.communication_direction,text,text)
from public, anon, authenticated;
grant execute on function public.record_portal_message(uuid,uuid,public.communication_direction,text,text)
to service_role;
