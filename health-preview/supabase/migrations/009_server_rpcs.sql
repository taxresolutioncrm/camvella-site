-- 009_server_rpcs.sql
-- Trusted server-only transactional operations.
-- Edge Functions call these using a server-side secret key.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function public.bootstrap_tenant(
  p_user_id uuid,
  p_org_name text,
  p_office_name text,
  p_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  new_org uuid;
  new_office uuid;
begin
  if p_user_id is null then
    raise exception 'user id required';
  end if;
  if length(trim(coalesce(p_org_name,''))) < 2 then
    raise exception 'organization name required';
  end if;
  if exists(select 1 from public.memberships where user_id=p_user_id and is_active=true) then
    raise exception 'user already has an active organization membership';
  end if;

  insert into public.organizations(name)
  values(trim(p_org_name))
  returning id into new_org;

  insert into public.offices(organization_id,name)
  values(new_org,coalesce(nullif(trim(p_office_name),''),'Main Office'))
  returning id into new_office;

  insert into public.memberships(organization_id,office_id,user_id,role)
  values(new_org,new_office,p_user_id,'agency_admin');

  insert into public.user_profiles(user_id,display_name)
  values(p_user_id,null)
  on conflict(user_id) do nothing;

  insert into public.notification_preferences(organization_id,user_id)
  values(new_org,p_user_id)
  on conflict(organization_id,user_id) do nothing;

  insert into public.audit_log(
    organization_id, office_id, actor_user_id, actor_type,
    action, entity_type, entity_id, after_json
  ) values (
    new_org,new_office,p_user_id,'server',
    'tenant.bootstrapped','organizations',new_org,
    jsonb_build_object('organization_id',new_org,'office_id',new_office,'email',p_email)
  );

  return jsonb_build_object('organization_id',new_org,'office_id',new_office);
end;
$$;

revoke all on function public.bootstrap_tenant(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.bootstrap_tenant(uuid,text,text,text) to service_role;

create or replace function public.accept_team_invite(
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
  inv public.team_invitations%rowtype;
begin
  if p_user_id is null or nullif(trim(p_email),'') is null or nullif(p_token,'') is null then
    raise exception 'user, email and token are required';
  end if;

  select * into inv
  from public.team_invitations
  where lower(email)=lower(trim(p_email))
    and token_hash=encode(digest(p_token,'sha256'),'hex')
    and accepted_at is null
    and expires_at > now()
  order by created_at desc
  limit 1
  for update;

  if inv.id is null then
    raise exception 'invalid or expired invitation';
  end if;

  insert into public.memberships(organization_id,office_id,user_id,role)
  values(inv.organization_id,inv.office_id,p_user_id,inv.role)
  on conflict(organization_id,user_id)
  do update set office_id=excluded.office_id, role=excluded.role, is_active=true;

  update public.team_invitations
  set accepted_at=now()
  where id=inv.id;

  insert into public.user_profiles(user_id)
  values(p_user_id)
  on conflict(user_id) do nothing;

  insert into public.notification_preferences(organization_id,user_id)
  values(inv.organization_id,p_user_id)
  on conflict(organization_id,user_id) do nothing;

  insert into public.audit_log(
    organization_id,office_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    inv.organization_id,inv.office_id,p_user_id,'server',
    'team_invitation.accepted','memberships',null,
    jsonb_build_object('invitation_id',inv.id,'role',inv.role)
  );

  return jsonb_build_object('organization_id',inv.organization_id,'office_id',inv.office_id,'role',inv.role);
end;
$$;

revoke all on function public.accept_team_invite(uuid,text,text) from public, anon, authenticated;
grant execute on function public.accept_team_invite(uuid,text,text) to service_role;

revoke all on function public.set_updated_at() from public, anon, authenticated;
