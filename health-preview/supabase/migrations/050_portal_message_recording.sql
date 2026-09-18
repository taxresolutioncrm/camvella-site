-- 050_portal_message_recording.sql
-- Atomic portal message recording for agency and client-portal actors.
-- DO NOT APPLY until the dedicated Supabase project is selected.

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
  thread_id uuid;
  communication_id uuid;
  thread_assignee uuid;
  actor_is_portal boolean:=false;
  actor_is_agency boolean:=false;
begin
  if p_actor_user_id is null or p_actor_user_id is distinct from (select auth.uid()) then
    raise exception 'actor mismatch';
  end if;

  if length(trim(coalesce(p_body,'')))<1 then
    raise exception 'message body is required';
  end if;

  select * into c
  from public.clients
  where id=p_client_id;

  if c.id is null then
    raise exception 'client not found';
  end if;

  actor_is_portal:=app_private.is_portal_user_for_client(c.id);
  actor_is_agency:=app_private.can_manage_client(c.id)
    or app_private.has_org_role(c.organization_id,array['compliance']::public.member_role[]);

  if p_direction='inbound' and not actor_is_portal then
    raise exception 'portal user is not authorized for this client';
  end if;

  if p_direction='outbound' and not actor_is_agency then
    raise exception 'agency user is not authorized for this client';
  end if;

  if p_direction='inbound' then
    thread_assignee:=c.assigned_user_id;
  else
    thread_assignee:=p_actor_user_id;
  end if;

  -- Reuse the latest open portal thread for the client when available.
  select t.id into thread_id
  from public.communication_threads t
  where t.organization_id=c.organization_id
    and t.client_id=c.id
    and t.status='open'
    and t.last_channel='portal'
  order by t.last_message_at desc nulls last,t.created_at desc
  limit 1
  for update;

  if thread_id is null then
    insert into public.communication_threads(
      organization_id,office_id,client_id,subject,last_channel,
      last_message_at,assigned_user_id,status
    ) values (
      c.organization_id,c.office_id,c.id,
      nullif(trim(coalesce(p_subject,'')),''),
      'portal',now(),thread_assignee,'open'
    )
    returning id into thread_id;
  else
    update public.communication_threads
    set last_channel='portal',
        last_message_at=now(),
        subject=coalesce(nullif(trim(coalesce(p_subject,'')),''),subject),
        assigned_user_id=coalesce(assigned_user_id,thread_assignee)
    where id=thread_id;
  end if;

  insert into public.communications(
    organization_id,office_id,thread_id,channel,direction,
    client_id,user_id,provider,provider_status,from_address,to_address,
    subject,body_text,body_preview,created_at,
    delivered_at,read_at
  ) values (
    c.organization_id,c.office_id,thread_id,'portal',p_direction,
    c.id,
    case when p_direction='outbound' then p_actor_user_id else null end,
    'internal_portal','delivered',
    case when p_direction='outbound' then 'agency_portal' else c.id::text end,
    case when p_direction='outbound' then c.id::text else 'agency_portal' end,
    nullif(trim(coalesce(p_subject,'')),''),
    trim(p_body),
    left(trim(p_body),240),
    now(),
    now(),
    case when p_direction='inbound' then null else now() end
  )
  returning id into communication_id;

  return jsonb_build_object(
    'thread_id',thread_id,
    'communication_id',communication_id,
    'direction',p_direction
  );
end;
$$;

revoke all on function public.record_portal_message(
  uuid,uuid,public.communication_direction,text,text
) from public, anon, authenticated;
grant execute on function public.record_portal_message(
  uuid,uuid,public.communication_direction,text,text
) to service_role;
