-- 031_public_slug_and_intake_integrity.sql
-- Makes public slugs globally resolvable and tightens public intake/booking validation.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.booking_links
drop constraint if exists booking_links_organization_id_slug_key;

create unique index booking_links_slug_uq
on public.booking_links(slug);

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

  if length(trim(coalesce(p_first_name,'')))<1
     or length(trim(coalesce(p_last_name,'')))<1 then
    raise exception 'first and last name are required';
  end if;

  if nullif(trim(coalesce(p_email,'')),'') is null
     and nullif(trim(coalesce(p_phone,'')),'') is null then
    raise exception 'email or phone is required';
  end if;

  if form_row.default_market is not null
     and p_market is not null
     and p_market<>form_row.default_market then
    raise exception 'market does not match intake form';
  end if;

  chosen_market:=coalesce(form_row.default_market,p_market);
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

revoke all on function public.submit_public_intake(text,text,text,text,text,public.market_type)
from public, anon, authenticated;
grant execute on function public.submit_public_intake(text,text,text,text,text,public.market_type)
to service_role;

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

  if type_row.market is null then
    raise exception 'public booking requires an ACA or Medicare appointment type';
  end if;

  if nullif(trim(coalesce(p_email,'')),'') is null
     and nullif(trim(coalesce(p_phone,'')),'') is null then
    raise exception 'email or phone is required';
  end if;

  if p_starts_at<=now() then
    raise exception 'appointment must be in the future';
  end if;

  slot_end:=p_starts_at+make_interval(mins=>type_row.duration_minutes);
  perform pg_advisory_xact_lock(hashtext(link_row.user_id::text));

  if exists(
    select 1 from public.appointments a
    where a.assigned_user_id=link_row.user_id
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
    nullif(trim(p_phone),''),type_row.market,'public_booking','appointment'
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

revoke all on function public.create_public_booking(text,timestamptz,text,text,text,text)
from public, anon, authenticated;
grant execute on function public.create_public_booking(text,timestamptz,text,text,text,text)
to service_role;
