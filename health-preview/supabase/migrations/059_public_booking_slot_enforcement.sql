-- 059_public_booking_slot_enforcement.sql
-- Returns timezone-aware public slots and rejects bookings outside configured availability.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop function if exists public.get_public_availability(text,date);

create or replace function public.get_public_availability(
  p_slug text,
  p_date date
)
returns table(
  starts_at timestamptz,
  timezone text,
  duration_minutes integer
)
language sql
security definer
set search_path = public
as $$
  with link as (
    select bl.id,bl.user_id,bl.appointment_type_id
    from public.booking_links bl
    where bl.slug=lower(trim(p_slug))
      and bl.is_active=true
    limit 1
  ),
  apt_type as (
    select at.id,at.duration_minutes
    from public.appointment_types at
    join link l on l.appointment_type_id=at.id
    where at.is_active=true
  ),
  rules as (
    select r.*
    from public.scheduling_availability_rules r
    join link l on l.user_id=r.user_id
    where r.is_active=true
      and r.day_of_week=extract(dow from p_date)::integer
  ),
  slots as (
    select
      gs as starts_at,
      r.timezone,
      t.duration_minutes,
      gs + make_interval(mins=>t.duration_minutes) as ends_at,
      l.user_id
    from rules r
    cross join link l
    cross join apt_type t
    cross join lateral generate_series(
      (p_date+r.start_time) at time zone r.timezone,
      ((p_date+r.end_time) at time zone r.timezone)-make_interval(mins=>t.duration_minutes),
      interval '15 minutes'
    ) gs
  )
  select distinct s.starts_at,s.timezone,s.duration_minutes
  from slots s
  where s.starts_at > now()
    and not exists (
      select 1
      from public.appointments a
      where a.assigned_user_id=s.user_id
        and a.status not in ('cancelled','no_show')
        and tstzrange(a.starts_at,a.starts_at+make_interval(mins=>a.duration_minutes),'[)')
            && tstzrange(s.starts_at,s.ends_at,'[)')
    )
  order by s.starts_at;
$$;

revoke all on function public.get_public_availability(text,date)
from public, anon, authenticated;
grant execute on function public.get_public_availability(text,date)
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
  slot_allowed boolean:=false;
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

  select exists(
    select 1
    from public.scheduling_availability_rules r
    where r.organization_id=link_row.organization_id
      and r.user_id=link_row.user_id
      and r.is_active=true
      and r.day_of_week=extract(dow from (p_starts_at at time zone r.timezone)::date)::integer
      and (p_starts_at at time zone r.timezone)::time >= r.start_time
      and (slot_end at time zone r.timezone)::time <= r.end_time
      and mod(
        floor(
          extract(epoch from (
            (p_starts_at at time zone r.timezone)::time - r.start_time
          ))/60
        )::integer,
        15
      )=0
  ) into slot_allowed;

  if not slot_allowed then
    raise exception 'requested time is outside configured availability';
  end if;

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
