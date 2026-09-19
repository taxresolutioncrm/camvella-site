-- 067_concurrency_hardening.sql
-- Serializes invitation/admin/thread mutations that can otherwise race under concurrent requests.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function public.create_team_invitation(
  p_actor_user_id uuid,
  p_organization_id uuid,
  p_office_id uuid,
  p_email text,
  p_role public.member_role,
  p_hours_valid integer default 72
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  raw_token text;
  invitation_id uuid;
  normalized_email text := lower(trim(p_email));
begin
  if normalized_email='' then
    raise exception 'email required';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('team-invite:'||p_organization_id::text||':'||normalized_email)
  );

  if not exists (
    select 1 from public.memberships m
    where m.user_id=p_actor_user_id
      and m.organization_id=p_organization_id
      and m.is_active=true
      and m.role='agency_admin'
  ) then
    raise exception 'only an agency administrator can invite team members';
  end if;

  raw_token:=encode(gen_random_bytes(32),'hex');

  select id into invitation_id
  from public.team_invitations
  where organization_id=p_organization_id
    and lower(email)=normalized_email
    and accepted_at is null
  order by created_at desc
  limit 1
  for update;

  if invitation_id is null then
    insert into public.team_invitations(
      organization_id,office_id,email,role,invited_by,token_hash,expires_at
    ) values (
      p_organization_id,p_office_id,normalized_email,p_role,p_actor_user_id,
      encode(digest(raw_token,'sha256'),'hex'),
      now()+make_interval(hours=>greatest(1,p_hours_valid))
    )
    returning id into invitation_id;
  else
    update public.team_invitations
    set office_id=p_office_id,
        role=p_role,
        invited_by=p_actor_user_id,
        token_hash=encode(digest(raw_token,'sha256'),'hex'),
        expires_at=now()+make_interval(hours=>greatest(1,p_hours_valid)),
        created_at=now()
    where id=invitation_id;
  end if;

  insert into public.audit_log(
    organization_id,office_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    p_organization_id,p_office_id,p_actor_user_id,'server',
    'team_invitation.created','team_invitations',invitation_id,
    jsonb_build_object('email',normalized_email,'role',p_role)
  );

  return jsonb_build_object(
    'invitation_id',invitation_id,
    'token',raw_token,
    'email',normalized_email
  );
end;
$$;

revoke all on function public.create_team_invitation(
  uuid,uuid,uuid,text,public.member_role,integer
) from public, anon, authenticated;
grant execute on function public.create_team_invitation(
  uuid,uuid,uuid,text,public.member_role,integer
) to service_role;

create or replace function public.create_portal_invitation(
  p_actor_user_id uuid,
  p_client_id uuid,
  p_email text,
  p_hours_valid integer default 72
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  raw_token text;
  invitation_id uuid;
  target_client public.clients%rowtype;
  normalized_email text := lower(trim(p_email));
begin
  select * into target_client
  from public.clients c
  where c.id=p_client_id;

  if target_client.id is null then
    raise exception 'client not found';
  end if;

  if normalized_email='' then
    raise exception 'email required';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(
      'portal-invite:'||
      target_client.organization_id::text||':'||
      target_client.id::text||':'||
      normalized_email
    )
  );

  if not exists (
    select 1
    from public.memberships m
    where m.user_id=p_actor_user_id
      and m.organization_id=target_client.organization_id
      and m.is_active=true
      and (
        m.role in ('agency_admin','manager')
        or (
          m.role='agent'
          and target_client.assigned_user_id=p_actor_user_id
          and (
            target_client.office_id is null
            or m.office_id=target_client.office_id
          )
        )
      )
  ) then
    raise exception 'actor cannot invite this client';
  end if;

  raw_token:=encode(gen_random_bytes(32),'hex');

  select id into invitation_id
  from public.portal_invitations
  where organization_id=target_client.organization_id
    and client_id=target_client.id
    and lower(email)=normalized_email
    and accepted_at is null
  order by created_at desc
  limit 1
  for update;

  if invitation_id is null then
    insert into public.portal_invitations(
      organization_id,client_id,email,token_hash,expires_at,created_by
    ) values (
      target_client.organization_id,target_client.id,normalized_email,
      encode(digest(raw_token,'sha256'),'hex'),
      now()+make_interval(hours=>greatest(1,p_hours_valid)),
      p_actor_user_id
    )
    returning id into invitation_id;
  else
    update public.portal_invitations
    set token_hash=encode(digest(raw_token,'sha256'),'hex'),
        expires_at=now()+make_interval(hours=>greatest(1,p_hours_valid)),
        created_by=p_actor_user_id,
        created_at=now()
    where id=invitation_id;
  end if;

  insert into public.audit_log(
    organization_id,office_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    target_client.organization_id,target_client.office_id,p_actor_user_id,'server',
    'portal_invitation.created','portal_invitations',invitation_id,
    jsonb_build_object('client_id',target_client.id,'email',normalized_email)
  );

  return jsonb_build_object(
    'invitation_id',invitation_id,
    'token',raw_token,
    'email',normalized_email
  );
end;
$$;

revoke all on function public.create_portal_invitation(uuid,uuid,text,integer)
from public, anon, authenticated;
grant execute on function public.create_portal_invitation(uuid,uuid,text,integer)
to service_role;

create or replace function public.accept_portal_invitation(
  p_user_id uuid,
  p_email text,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  inv public.portal_invitations%rowtype;
  portal_id uuid;
  existing_client uuid;
begin
  if p_user_id is null
     or nullif(trim(p_email),'') is null
     or nullif(trim(p_token),'') is null then
    raise exception 'user, email and token are required';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('portal-account-user:'||p_user_id::text)
  );

  select * into inv
  from public.portal_invitations
  where lower(email)=lower(trim(p_email))
    and token_hash=encode(digest(p_token,'sha256'),'hex')
    and accepted_at is null
    and expires_at > now()
  order by created_at desc
  limit 1
  for update;

  if inv.id is null then
    raise exception 'invalid or expired portal invitation';
  end if;

  select p.client_id into existing_client
  from public.client_portal_accounts p
  where p.user_id=p_user_id
    and p.status='active'
  limit 1
  for update;

  if existing_client is not null
     and existing_client<>inv.client_id then
    raise exception 'this login is already linked to another active client portal';
  end if;

  insert into public.client_portal_accounts(
    organization_id,client_id,user_id,status
  )
  values(inv.organization_id,inv.client_id,p_user_id,'active')
  on conflict(organization_id,client_id,user_id)
  do update set status='active'
  returning id into portal_id;

  update public.portal_invitations
  set accepted_at=now()
  where id=inv.id;

  insert into public.user_profiles(user_id)
  values(p_user_id)
  on conflict(user_id) do nothing;

  insert into public.audit_log(
    organization_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    inv.organization_id,p_user_id,'server',
    'portal_invitation.accepted','client_portal_accounts',portal_id,
    jsonb_build_object('client_id',inv.client_id,'invitation_id',inv.id)
  );

  return jsonb_build_object(
    'portal_account_id',portal_id,
    'organization_id',inv.organization_id,
    'client_id',inv.client_id
  );
end;
$$;

revoke all on function public.accept_portal_invitation(uuid,text,text)
from public, anon, authenticated;
grant execute on function public.accept_portal_invitation(uuid,text,text)
to service_role;

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
      raise exception 'cannot deactivate or demote the final active agency administrator';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_last_active_agency_admin()
from public, anon, authenticated;

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
  active_assignee uuid;
  thread_assignee uuid;
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

  perform pg_advisory_xact_lock(
    hashtext('portal-thread:'||c.organization_id::text||':'||c.id::text)
  );

  select m.user_id into active_assignee
  from public.memberships m
  where m.organization_id=c.organization_id
    and m.user_id=c.assigned_user_id
    and m.is_active=true
  limit 1;

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

  thread_assignee:=case
    when p_direction='outbound' then p_actor_user_id
    else active_assignee
  end;

  insert into public.portal_messages(
    organization_id,office_id,client_id,direction,subject,body_text,
    sender_user_id,created_at
  ) values (
    c.organization_id,c.office_id,c.id,p_direction,
    nullif(trim(p_subject),''),trim(p_body),p_actor_user_id,now_at
  )
  returning id into portal_message_id;

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
      last_message_at,assigned_user_id,status,created_at
    ) values (
      c.organization_id,c.office_id,c.id,
      coalesce(nullif(trim(p_subject),''),'Portal message'),
      'portal',now_at,thread_assignee,'open',now_at
    )
    returning id into thread_id;
  else
    update public.communication_threads
    set last_message_at=now_at,
        subject=coalesce(nullif(trim(p_subject),''),subject),
        assigned_user_id=coalesce(assigned_user_id,thread_assignee)
    where id=thread_id;
  end if;

  insert into public.communications(
    organization_id,office_id,thread_id,channel,direction,client_id,user_id,
    provider,provider_status,from_address,to_address,subject,body_text,
    body_preview,created_at
  ) values (
    c.organization_id,c.office_id,thread_id,'portal',p_direction,c.id,
    case when p_direction='outbound' then p_actor_user_id else null end,
    'client_portal',
    case when p_direction='outbound' then 'delivered' else 'received' end,
    case when p_direction='outbound' then 'agency_portal' else c.id::text end,
    case when p_direction='outbound' then c.id::text else 'agency_portal' end,
    nullif(trim(p_subject),''),trim(p_body),left(trim(p_body),240),now_at
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

revoke all on function public.record_portal_message(
  uuid,uuid,public.communication_direction,text,text
) from public, anon, authenticated;
grant execute on function public.record_portal_message(
  uuid,uuid,public.communication_direction,text,text
) to service_role;
