-- 066_portal_account_single_active_user.sql
-- The current portal runtime has one client context per authenticated user.
-- Enforce that contract at the database boundary.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create unique index client_portal_accounts_active_user_uq
on public.client_portal_accounts(user_id)
where status='active';

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
  limit 1;

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
    jsonb_build_object(
      'client_id',inv.client_id,
      'invitation_id',inv.id
    )
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
