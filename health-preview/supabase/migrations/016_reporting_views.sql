-- 016_reporting_views.sql
-- RLS-preserving reporting views used by dashboards.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create view public.v_agent_production
with (security_invoker = true)
as
select
  e.organization_id,
  e.assigned_user_id,
  e.market,
  count(*) as enrollment_count,
  count(*) filter (where e.lifecycle_status='active') as active_count,
  count(*) filter (where e.lifecycle_status in ('submitted','pending','approved')) as in_flight_count,
  count(*) filter (where e.lifecycle_status in ('denied','cancelled')) as unsuccessful_count
from public.enrollments e
group by e.organization_id,e.assigned_user_id,e.market;

create view public.v_service_queue
with (security_invoker = true)
as
select
  sr.id,
  sr.organization_id,
  sr.office_id,
  sr.client_id,
  c.first_name,
  c.last_name,
  sr.request_type,
  sr.priority,
  sr.status,
  sr.assigned_user_id,
  sr.sla_due_at,
  sr.created_at,
  case
    when sr.status <> 'resolved' and sr.sla_due_at is not null and sr.sla_due_at < now() then true
    else false
  end as is_sla_breached
from public.service_requests sr
join public.clients c on c.id=sr.client_id;

create view public.v_communication_inbox
with (security_invoker = true)
as
select
  t.id as thread_id,
  t.organization_id,
  t.office_id,
  t.client_id,
  t.lead_id,
  t.subject,
  t.last_channel,
  t.last_message_at,
  t.assigned_user_id,
  t.status,
  (
    select count(*)
    from public.communications c
    where c.thread_id=t.id
      and c.direction='inbound'
      and c.read_at is null
  ) as unread_count
from public.communication_threads t;

create view public.v_agent_license_status
with (security_invoker = true)
as
select
  l.id,
  l.organization_id,
  l.user_id,
  l.state,
  l.license_number,
  l.license_type,
  l.status,
  l.expires_at,
  case
    when l.expires_at is null then 'unknown'
    when l.expires_at < current_date then 'expired'
    when l.expires_at <= current_date + 45 then 'due_soon'
    else 'current'
  end as expiration_status
from public.agent_licenses l;

create view public.v_carrier_readiness
with (security_invoker = true)
as
select
  cc.id,
  cc.organization_id,
  cc.carrier_id,
  c.name as carrier_name,
  cc.user_id,
  cc.state,
  cc.market,
  cc.appointment_status,
  cc.certification_status,
  cc.certification_expires_at,
  case
    when cc.appointment_status <> 'active' then 'appointment_pending'
    when cc.certification_status is distinct from 'current' then 'certification_review'
    when cc.certification_expires_at is not null and cc.certification_expires_at <= current_date + 45 then 'certification_due'
    else 'ready'
  end as readiness_status
from public.carrier_contracts cc
join public.carriers c on c.id=cc.carrier_id;

grant select on public.v_agent_production to authenticated;
grant select on public.v_service_queue to authenticated;
grant select on public.v_communication_inbox to authenticated;
grant select on public.v_agent_license_status to authenticated;
grant select on public.v_carrier_readiness to authenticated;
