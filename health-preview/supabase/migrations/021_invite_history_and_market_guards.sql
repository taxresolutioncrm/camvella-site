-- 021_invite_history_and_market_guards.sql
-- Preserves invitation history and tightens market/date/url integrity.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.team_invitations
drop constraint if exists team_invitations_organization_id_email_key;

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
  if not exists (
    select 1 from public.memberships m
    where m.user_id=p_actor_user_id
      and m.organization_id=p_organization_id
      and m.is_active=true
      and m.role='agency_admin'
  ) then
    raise exception 'only an agency administrator can invite team members';
  end if;

  if normalized_email='' then
    raise exception 'email required';
  end if;

  raw_token := encode(gen_random_bytes(32),'hex');

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

  return jsonb_build_object('invitation_id',invitation_id,'token',raw_token,'email',normalized_email);
end;
$$;

revoke all on function public.create_team_invitation(uuid,uuid,uuid,text,public.member_role,integer) from public, anon, authenticated;
grant execute on function public.create_team_invitation(uuid,uuid,uuid,text,public.member_role,integer) to service_role;

create or replace function app_private.guard_enrollment_relationships()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  product_carrier uuid;
  product_market public.market_type;
begin
  if new.carrier_product_id is not null then
    select carrier_id,market into product_carrier,product_market
    from public.carrier_products
    where id=new.carrier_product_id;

    if new.carrier_id is null or product_carrier is distinct from new.carrier_id then
      raise exception 'enrollment carrier product does not belong to selected carrier';
    end if;

    if product_market is distinct from new.market then
      raise exception 'enrollment carrier product market does not match enrollment market';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function app_private.guard_enrollment_relationships() from public, anon, authenticated;

create or replace function app_private.guard_plan_comparison_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  comparison_market public.market_type;
  product_market public.market_type;
begin
  if new.carrier_product_id is null then return new; end if;

  select market into comparison_market
  from public.plan_comparisons
  where id=new.comparison_id;

  select market into product_market
  from public.carrier_products
  where id=new.carrier_product_id;

  if product_market is distinct from comparison_market then
    raise exception 'comparison product market does not match comparison market';
  end if;

  return new;
end;
$$;
revoke all on function app_private.guard_plan_comparison_item() from public, anon, authenticated;

create trigger plan_comparison_item_market_guard
before insert or update on public.plan_comparison_items
for each row execute function app_private.guard_plan_comparison_item();

alter table public.agent_licenses
add constraint agent_licenses_date_order_chk
check (expires_at is null or issued_at is null or expires_at >= issued_at);

alter table public.booking_links
add constraint booking_links_slug_chk
check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$');
