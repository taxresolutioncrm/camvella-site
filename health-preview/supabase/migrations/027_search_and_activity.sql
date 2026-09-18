-- 027_search_and_activity.sql
-- Workspace search + client activity feed.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create extension if not exists pg_trgm;

create index if not exists clients_name_trgm_idx
on public.clients using gin ((first_name||' '||last_name) gin_trgm_ops);

create index if not exists leads_name_trgm_idx
on public.leads using gin ((first_name||' '||last_name) gin_trgm_ops);

create index if not exists policies_number_trgm_idx
on public.policies using gin (policy_number gin_trgm_ops)
where policy_number is not null;

create or replace function public.search_workspace(
  p_query text,
  p_limit integer default 25
)
returns table(
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  organization_id uuid,
  office_id uuid
)
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select nullif(trim(p_query),'') as term, greatest(1,least(coalesce(p_limit,25),100)) as lim
  ),
  client_hits as (
    select
      'client'::text as entity_type,
      c.id as entity_id,
      c.first_name||' '||c.last_name as title,
      concat_ws(' · ',c.market::text,c.email,c.phone) as subtitle,
      c.organization_id,
      c.office_id,
      greatest(
        similarity(lower(c.first_name||' '||c.last_name),lower(q.term)),
        case when lower(coalesce(c.email,'')) like '%'||lower(q.term)||'%' then 0.9 else 0 end,
        case when coalesce(c.phone,'') like '%'||q.term||'%' then 0.9 else 0 end
      ) as rank
    from public.clients c cross join q
    where q.term is not null
      and (
        lower(c.first_name||' '||c.last_name) % lower(q.term)
        or lower(coalesce(c.email,'')) like '%'||lower(q.term)||'%'
        or coalesce(c.phone,'') like '%'||q.term||'%'
      )
  ),
  lead_hits as (
    select
      'lead'::text,
      l.id,
      l.first_name||' '||l.last_name,
      concat_ws(' · ',l.market::text,l.stage,l.email,l.phone),
      l.organization_id,
      l.office_id,
      greatest(
        similarity(lower(l.first_name||' '||l.last_name),lower(q.term)),
        case when lower(coalesce(l.email,'')) like '%'||lower(q.term)||'%' then 0.9 else 0 end,
        case when coalesce(l.phone,'') like '%'||q.term||'%' then 0.9 else 0 end
      )
    from public.leads l cross join q
    where q.term is not null
      and (
        lower(l.first_name||' '||l.last_name) % lower(q.term)
        or lower(coalesce(l.email,'')) like '%'||lower(q.term)||'%'
        or coalesce(l.phone,'') like '%'||q.term||'%'
      )
  ),
  policy_hits as (
    select
      'policy'::text,
      p.id,
      coalesce(p.policy_number,'Policy'),
      concat_ws(' · ',c.first_name||' '||c.last_name,cr.name,p.status),
      p.organization_id,
      p.office_id,
      case when lower(coalesce(p.policy_number,'')) like '%'||lower(q.term)||'%' then 1.0 else 0.5 end
    from public.policies p
    join public.clients c on c.id=p.client_id
    join public.carriers cr on cr.id=p.carrier_id
    cross join q
    where q.term is not null
      and lower(coalesce(p.policy_number,'')) like '%'||lower(q.term)||'%'
  )
  select entity_type,entity_id,title,subtitle,organization_id,office_id
  from (
    select * from client_hits
    union all select * from lead_hits
    union all select * from policy_hits
  ) hits
  order by rank desc,title
  limit (select lim from q);
$$;

revoke all on function public.search_workspace(text,integer) from public, anon;
grant execute on function public.search_workspace(text,integer) to authenticated;

create view public.v_client_activity
with (security_invoker = true)
as
select
  pe.organization_id,
  p.office_id,
  p.client_id,
  pe.created_at as occurred_at,
  'policy_event'::text as activity_type,
  pe.event_type as title,
  pe.summary as detail,
  pe.id as activity_id
from public.policy_events pe
join public.policies p on p.id=pe.policy_id

union all

select
  c.organization_id,
  c.office_id,
  c.client_id,
  c.created_at,
  'communication'::text,
  c.channel::text||' '||c.direction::text,
  coalesce(c.subject,c.body_preview,c.provider_status),
  c.id
from public.communications c
where c.client_id is not null

union all

select
  sr.organization_id,
  sr.office_id,
  sr.client_id,
  sr.created_at,
  'service_request'::text,
  sr.request_type,
  sr.status,
  sr.id
from public.service_requests sr

union all

select
  d.organization_id,
  d.office_id,
  d.client_id,
  d.created_at,
  'document'::text,
  d.document_type,
  d.file_name,
  d.id
from public.documents d
where d.client_id is not null

union all

select
  r.organization_id,
  r.office_id,
  r.client_id,
  r.created_at,
  'renewal'::text,
  'Renewal '||r.risk_level,
  r.outreach_status,
  r.id
from public.renewals r;

grant select on public.v_client_activity to authenticated;
