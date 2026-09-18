-- 013_invitation_rpcs.sql
-- Server-only invitation creation/acceptance helpers.
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
begin
  if not exists (
    select 1 from public.memberships m
    where m.user_id=p_actor_user_id
      and m.organization_id=p_organization_id
      and m.is_active=true
      and m.role='agency_admin'
  ) then
    raise exception 'only an agency administrator can invite team members';
  end if;

  raw_token := encode(gen_random_bytes(32),'hex');

  insert into public.team_invitations(
    organization_id,office_id,email,role,invited_by,token_hash,expires_at
  ) values (
    p_organization_id,p_office_id,lower(trim(p_email)),p_role,p_actor_user_id,
    encode(digest(raw_token,'sha256'),'hex'),
    now() + make_interval(hours => greatest(1,p_hours_valid))
  )
  on conflict (organization_id,email)
  do update set
    office_id=excluded.office_id,
    role=excluded.role,
    invited_by=excluded.invited_by,
    token_hash=excluded.token_hash,
    expires_at=excluded.expires_at,
    accepted_at=null,
    created_at=now()
  returning id into invitation_id;

  insert into public.audit_log(
    organization_id,office_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    p_organization_id,p_office_id,p_actor_user_id,'server',
    'team_invitation.created','team_invitations',invitation_id,
    jsonb_build_object('email',lower(trim(p_email)),'role',p_role)
  );

  return jsonb_build_object('invitation_id',invitation_id,'token',raw_token,'email',lower(trim(p_email)));
end;
$$;

revoke all on function public.create_team_invitation(uuid,uuid,uuid,text,public.member_role,integer) from public, anon, authenticated;
grant execute on function public.create_team_invitation(uuid,uuid,uuid,text,public.member_role,integer) to service_role;

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
  target_org uuid;
  target_office uuid;
begin
  select c.organization_id,c.office_id
  into target_org,target_office
  from public.clients c
  where c.id=p_client_id;

  if target_org is null then
    raise exception 'client not found';
  end if;

  if not exists (
    select 1 from public.memberships m
    where m.user_id=p_actor_user_id
      and m.organization_id=target_org
      and m.is_active=true
      and (
        m.role in ('agency_admin','manager')
        or (m.role='agent' and (target_office is null or m.office_id=target_office))
      )
  ) then
    raise exception 'actor cannot invite this client';
  end if;

  raw_token := encode(gen_random_bytes(32),'hex');

  insert into public.portal_invitations(
    organization_id,client_id,email,token_hash,expires_at,created_by
  ) values (
    target_org,p_client_id,lower(trim(p_email)),
    encode(digest(raw_token,'sha256'),'hex'),
    now() + make_interval(hours => greatest(1,p_hours_valid)),
    p_actor_user_id
  )
  returning id into invitation_id;

  insert into public.audit_log(
    organization_id,office_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    target_org,target_office,p_actor_user_id,'server',
    'portal_invitation.created','portal_invitations',invitation_id,
    jsonb_build_object('client_id',p_client_id,'email',lower(trim(p_email)))
  );

  return jsonb_build_object('invitation_id',invitation_id,'token',raw_token,'email',lower(trim(p_email)));
end;
$$;

revoke all on function public.create_portal_invitation(uuid,uuid,text,integer) from public, anon, authenticated;
grant execute on function public.create_portal_invitation(uuid,uuid,text,integer) to service_role;

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
begin
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

  insert into public.client_portal_accounts(organization_id,client_id,user_id,status)
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

  return jsonb_build_object('portal_account_id',portal_id,'organization_id',inv.organization_id,'client_id',inv.client_id);
end;
$$;

revoke all on function public.accept_portal_invitation(uuid,text,text) from public, anon, authenticated;
grant execute on function public.accept_portal_invitation(uuid,text,text) to service_role;
