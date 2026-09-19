-- 073_identity_mode_lock_alignment.sql
-- Uses one per-user advisory lock for every identity-mode transition.
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

  -- Must use the same lock namespace as team/portal invitation acceptance.
  perform pg_advisory_xact_lock(
    hashtext('identity-mode:'||p_user_id::text)
  );

  if exists(
    select 1
    from public.memberships m
    where m.user_id=p_user_id
      and m.is_active=true
  ) then
    raise exception 'user already has an active organization membership';
  end if;

  if exists(
    select 1
    from public.client_portal_accounts p
    where p.user_id=p_user_id
      and p.status='active'
  ) then
    raise exception 'client portal identities cannot bootstrap an agency workspace';
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
    organization_id,office_id,actor_user_id,actor_type,
    action,entity_type,entity_id,after_json
  ) values (
    new_org,new_office,p_user_id,'server',
    'tenant.bootstrapped','organizations',new_org,
    jsonb_build_object(
      'organization_id',new_org,
      'office_id',new_office,
      'email',p_email
    )
  );

  return jsonb_build_object(
    'organization_id',new_org,
    'office_id',new_office
  );
end;
$$;

revoke all on function public.bootstrap_tenant(uuid,text,text,text)
from public, anon, authenticated;
grant execute on function public.bootstrap_tenant(uuid,text,text,text)
to service_role;
