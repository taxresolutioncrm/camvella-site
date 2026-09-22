-- 091_public_availability_tenant_alignment.sql
-- Prevents an agent's availability rules from another agency from appearing on a public booking link.
-- Also prunes stale rate-limit windows opportunistically.
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
    select
      bl.id,
      bl.organization_id,
      bl.user_id,
      bl.appointment_type_id
    from public.booking_links bl
    where bl.slug=lower(trim(p_slug))
      and bl.is_active=true
    limit 1
  ),
  apt_type as (
    select at.id,at.duration_minutes
    from public.appointment_types at
    join link l
      on l.appointment_type_id=at.id
     and at.organization_id=l.organization_id
    where at.is_active=true
  ),
  rules as (
    select r.*
    from public.scheduling_availability_rules r
    join link l
      on l.user_id=r.user_id
     and l.organization_id=r.organization_id
    where r.is_active=true
      and r.day_of_week=extract(dow from p_date)::integer
  ),
  slots as (
    select
      gs as starts_at,
      r.timezone,
      t.duration_minutes,
      gs+make_interval(mins=>t.duration_minutes) as ends_at,
      l.organization_id,
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
  where s.starts_at>now()
    and not exists(
      select 1
      from public.appointments a
      where a.organization_id=s.organization_id
        and a.assigned_user_id=s.user_id
        and a.status not in ('cancelled','no_show')
        and tstzrange(
              a.starts_at,
              a.starts_at+make_interval(mins=>a.duration_minutes),
              '[)'
            )
            &&
            tstzrange(s.starts_at,s.ends_at,'[)')
    )
  order by s.starts_at;
$$;

revoke all on function public.get_public_availability(text,date)
from public, anon, authenticated;
grant execute on function public.get_public_availability(text,date)
to service_role;

create or replace function public.consume_public_rate_limit(
  p_endpoint text,
  p_ip_hash text,
  p_limit integer default 10,
  p_window_seconds integer default 60
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  bucket timestamptz;
  new_count integer;
begin
  if p_limit<1 or p_window_seconds<1 then
    raise exception 'invalid rate limit configuration';
  end if;

  bucket:=to_timestamp(
    floor(extract(epoch from now())/p_window_seconds)*p_window_seconds
  );

  delete from public.public_rate_limit_windows
  where window_start<now()-interval '24 hours';

  insert into public.public_rate_limit_windows(
    endpoint,ip_hash,window_start,request_count
  )
  values(p_endpoint,p_ip_hash,bucket,1)
  on conflict(endpoint,ip_hash,window_start)
  do update
  set request_count=public.public_rate_limit_windows.request_count+1
  returning request_count into new_count;

  return new_count<=p_limit;
end;
$$;

revoke all on function public.consume_public_rate_limit(text,text,integer,integer)
from public, anon, authenticated;
grant execute on function public.consume_public_rate_limit(text,text,integer,integer)
to service_role;
