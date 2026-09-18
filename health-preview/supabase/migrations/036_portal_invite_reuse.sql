-- 036_portal_invite_reuse.sql
-- Reissues active portal invitations without destroying accepted invitation history.
-- DO NOT APPLY until the dedicated Supabase project is selected.

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
  normalized_email text := lower(trim(p_email));
begin
  select c.organization_id,c.office_id
  into target_org,target_office
  from public.clients c
  where c.id=p_client_id;

  if target_org is null then
    raise exception 'client not found';
  end if;

  if normalized_email='' then
    raise exception 'email required';
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

  raw_token:=encode(gen_random_bytes(32),'hex');

  select id into invitation_id
  from public.portal_invitations
  where organization_id=target_org
    and client_id=p_client_id
    and lower(email)=normalized_email
    and accepted_at is null
  order by created_at desc
  limit 1
  for update;

  if invitation_id is null then
    insert into public.portal_invitations(
      organization_id,client_id,email,token_hash,expires_at,created_by
    ) values (
      target_org,p_client_id,normalized_email,
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
    target_org,target_office,p_actor_user_id,'server',
    'portal_invitation.created','portal_invitations',invitation_id,
    jsonb_build_object('client_id',p_client_id,'email',normalized_email)
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
