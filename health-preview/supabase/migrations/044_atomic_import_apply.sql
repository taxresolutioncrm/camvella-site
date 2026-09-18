-- 044_atomic_import_apply.sql
-- Atomically applies validated import rows so retries cannot duplicate partial chunks.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function public.apply_import_rows(
  p_job_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.import_jobs%rowtype;
  row_count integer;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'import payload must be a JSON array';
  end if;

  row_count:=jsonb_array_length(p_rows);
  if row_count<1 or row_count>2000 then
    raise exception 'import payload must contain between 1 and 2000 rows';
  end if;

  select * into job
  from public.import_jobs
  where id=p_job_id
  for update;

  if job.id is null then
    raise exception 'import job not found';
  end if;

  if job.status <> 'processing' then
    raise exception 'import job is not in processing state';
  end if;

  if job.import_type='leads' then
    insert into public.leads(
      organization_id,office_id,assigned_user_id,
      first_name,last_name,email,phone,market,source,stage,score
    )
    select
      job.organization_id,
      job.office_id,
      x.assigned_user_id,
      x.first_name,
      x.last_name,
      x.email,
      x.phone,
      x.market::public.market_type,
      x.source,
      x.stage,
      x.score
    from jsonb_to_recordset(p_rows) as x(
      assigned_user_id uuid,
      first_name text,
      last_name text,
      email text,
      phone text,
      market text,
      source text,
      stage text,
      score integer
    );

  elsif job.import_type='clients' then
    insert into public.clients(
      organization_id,office_id,assigned_user_id,
      first_name,last_name,email,phone,market,portal_status,renewal_risk
    )
    select
      job.organization_id,
      job.office_id,
      x.assigned_user_id,
      x.first_name,
      x.last_name,
      x.email,
      x.phone,
      x.market::public.market_type,
      x.portal_status,
      x.renewal_risk
    from jsonb_to_recordset(p_rows) as x(
      assigned_user_id uuid,
      first_name text,
      last_name text,
      email text,
      phone text,
      market text,
      portal_status text,
      renewal_risk text
    );

  elsif job.import_type='carrier_products' then
    insert into public.carrier_products(
      organization_id,carrier_id,market,product_name,product_type,
      state,plan_year,external_product_id,status
    )
    select
      job.organization_id,
      x.carrier_id,
      x.market::public.market_type,
      x.product_name,
      x.product_type,
      x.state,
      x.plan_year,
      x.external_product_id,
      x.status
    from jsonb_to_recordset(p_rows) as x(
      carrier_id uuid,
      market text,
      product_name text,
      product_type text,
      state text,
      plan_year integer,
      external_product_id text,
      status text
    );
  else
    raise exception 'unsupported import type: %',job.import_type;
  end if;

  update public.import_jobs
  set status='complete',
      rows_imported=row_count,
      rows_failed=0,
      finished_at=now()
  where id=job.id;

  return jsonb_build_object('rows_imported',row_count,'status','complete');
end;
$$;

revoke all on function public.apply_import_rows(uuid,jsonb)
from public, anon, authenticated;
grant execute on function public.apply_import_rows(uuid,jsonb)
to service_role;
