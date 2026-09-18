-- 025_public_forms_and_booking_rpcs.sql
-- Safe public intake + booking mapping and transactional server RPCs.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create table public.public_intake_forms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_id uuid references public.offices(id) on delete set null,
  assigned_user_id uuid references auth.users(id) on delete set null,
  slug text not null,
  default_market public.market_type,
  source text not null default 'website',
  is_active boolean not null default true,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(slug),
  check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$')
);
create index public_intake_forms_org_idx on public.public_intake_forms(organization_id,is_active);

alter table public.public_intake_forms enable row level security;

create policy public_intake_forms_select on public.public_intake_forms
for select to authenticated
using (organization_id in (select app_private.current_org_ids()));

create policy public_intake_forms_write on public.public_intake_forms
for all to authenticated
using (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
)
with check (
  app_private.can_access_office(organization_id,office_id)
  and app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
);

create trigger public_intake_forms_set_updated_at before update on public.public_intake_forms
for each row execute function public.set_updated_at();

create trigger tenant_public_intake_forms_office_id
before insert or update on public.public_intake_forms
for each row execute function app_private.guard_parent_organization('offices','office_id');

create trigger userorg_public_intake_forms_assigned_user_id
before insert or update on public.public_intake_forms
for each row execute function app_private.guard_user_organization('assigned_user_id');

create trigger audit_public_intake_forms after insert or update or delete on public.public_intake_forms
for each row execute function app_private.audit_row_change();

grant select,insert,update,delete on public.public_intake_forms to authenticated;

create or replace function public.submit_public_intake(
  p_slug text,
  p_first_name text,
  p_last_name text,
  p_email text,
  p_phone text,
  p_market public.market_type default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  form_row public.public_intake_forms%rowtype;
  lead_id uuid;
  chosen_market public.market_type;
begin
  select * into form_row
  from public.public_intake_forms
  where slug=lower(trim(p_slug))
    and is_active=true
  limit 1;

  if form_row.id is null then
    raise exception 'intake form not found';
  end if;

  if length(trim(coalesce(p_first_name,'')))<1 or length(trim(coalesce(p_last_name,'')))<1 then
    raise exception 'first and last name are required';
  end if;

  chosen_market:=coalesce(p_market,form_row.default_market);
  if chosen_market is null then
    raise exception 'market is required';
  end if;

  insert into public.leads(
    organization_id,office_id,assigned_user_id,
    first_name,last_name,email,phone,market,source,stage
  ) values (
    form_row.organization_id,form_row.office_id,form_row.assigned_user_id,
    trim(p_first_name),trim(p_last_name),nullif(trim(p_email),''),
    nullif(trim(p_phone),''),chosen_market,form_row.source,'new'
  )
  returning id into lead_id;

  return jsonb_build_object('lead_id',lead_id);
end;
$$;

revoke all on function public.submit_public_intake(text,text,text,text,text,public.market_type) from public, anon, authenticated;
grant execute on function public.submit_public_intake(text,text,text,text,text,public.market_type) to service_role;

create or replace function public.create_public_booking(
  p_slug text,
  p_starts_at timestamptz,
  p_first_name text,
  p_last_name text,
  p_email text,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  link_row public.booking_links%rowtype;
  type_row public.appointment_types%rowtype;
  lead_id uuid;
  appointment_id uuid;
  slot_end timestamptz;
begin
  select * into link_row
  from public.booking_links
  where slug=lower(trim(p_slug))
    and is_active=true
  limit 1;

  if link_row.id is null then
    raise exception 'booking link not found';
  end if;

  select * into type_row
  from public.appointment_types
  where id=link_row.appointment_type_id
    and is_active=true;

  if type_row.id is null then
    raise exception 'appointment type unavailable';
  end if;

  if p_starts_at<=now() then
    raise exception 'appointment must be in the future';
  end if;

  slot_end:=p_starts_at+make_interval(mins=>type_row.duration_minutes);

  -- Serialize bookings per assigned user to avoid simultaneous double booking.
  perform pg_advisory_xact_lock(hashtext(coalesce(link_row.user_id::text,link_row.id::text)));

  if exists(
    select 1 from public.appointments a
    where a.assigned_user_id is not distinct from link_row.user_id
      and a.status not in ('cancelled','no_show')
      and tstzrange(a.starts_at,a.starts_at+make_interval(mins=>a.duration_minutes),'[)')
          && tstzrange(p_starts_at,slot_end,'[)')
  ) then
    raise exception 'requested time is no longer available';
  end if;

  insert into public.leads(
    organization_id,office_id,assigned_user_id,
    first_name,last_name,email,phone,market,source,stage
  ) values (
    link_row.organization_id,link_row.office_id,link_row.user_id,
    trim(p_first_name),trim(p_last_name),nullif(trim(p_email),''),
    nullif(trim(p_phone),''),coalesce(type_row.market,'aca'),'public_booking','appointment'
  )
  returning id into lead_id;

  insert into public.appointments(
    organization_id,office_id,lead_id,assigned_user_id,
    appointment_type,starts_at,duration_minutes,status
  ) values (
    link_row.organization_id,link_row.office_id,lead_id,link_row.user_id,
    type_row.name,p_starts_at,type_row.duration_minutes,'scheduled'
  )
  returning id into appointment_id;

  return jsonb_build_object('appointment_id',appointment_id,'lead_id',lead_id);
end;
$$;

revoke all on function public.create_public_booking(text,timestamptz,text,text,text,text) from public, anon, authenticated;
grant execute on function public.create_public_booking(text,timestamptz,text,text,text,text) to service_role;
