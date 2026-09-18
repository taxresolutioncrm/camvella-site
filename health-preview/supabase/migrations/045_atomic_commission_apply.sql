-- 045_atomic_commission_apply.sql
-- Atomically applies matched commission lines/exceptions and finalizes a statement.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function public.apply_commission_statement(
  p_statement_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  statement public.commission_statements%rowtype;
  imported_count integer;
  exception_count integer;
  statement_total numeric(14,2);
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'commission payload must be a JSON array';
  end if;

  imported_count := jsonb_array_length(p_rows);
  if imported_count < 1 or imported_count > 10000 then
    raise exception 'commission payload must contain between 1 and 10000 rows';
  end if;

  select * into statement
  from public.commission_statements
  where id=p_statement_id
  for update;

  if statement.id is null then
    raise exception 'commission statement not found';
  end if;

  if statement.import_status <> 'processing' then
    raise exception 'commission statement is not in processing state';
  end if;

  if exists(select 1 from public.commission_lines where statement_id=statement.id) then
    raise exception 'commission statement already has imported lines';
  end if;

  with inserted as (
    insert into public.commission_lines(
      organization_id,
      statement_id,
      external_member_id,
      external_policy_number,
      client_id,
      policy_id,
      producer_external_id,
      user_id,
      commission_type,
      gross_amount,
      split_amount,
      net_amount,
      effective_date,
      paid_date,
      match_status,
      exception_reason
    )
    select
      statement.organization_id,
      statement.id,
      x.external_member_id,
      x.external_policy_number,
      x.client_id,
      x.policy_id,
      x.producer_external_id,
      x.user_id,
      x.commission_type,
      x.gross_amount,
      x.split_amount,
      x.net_amount,
      x.effective_date,
      x.paid_date,
      x.match_status,
      x.exception_reason
    from jsonb_to_recordset(p_rows) as x(
      external_member_id text,
      external_policy_number text,
      client_id uuid,
      policy_id uuid,
      producer_external_id text,
      user_id uuid,
      commission_type text,
      gross_amount numeric(14,2),
      split_amount numeric(14,2),
      net_amount numeric(14,2),
      effective_date date,
      paid_date date,
      match_status text,
      exception_reason text
    )
    returning id,match_status,exception_reason,net_amount
  ),
  exceptions as (
    insert into public.commission_exceptions(
      organization_id,
      commission_line_id,
      reason,
      amount,
      status
    )
    select
      statement.organization_id,
      i.id,
      coalesce(i.exception_reason,'Unmatched commission line'),
      i.net_amount,
      'open'
    from inserted i
    where i.match_status <> 'matched'
    returning id
  )
  select
    (select count(*) from exceptions),
    (select coalesce(sum(net_amount),0) from inserted)
  into exception_count,statement_total;

  update public.commission_statements
  set import_status='complete',
      row_count=imported_count,
      total_amount=statement_total
  where id=statement.id;

  return jsonb_build_object(
    'rows_imported',imported_count,
    'exceptions',exception_count,
    'total_amount',statement_total,
    'status','complete'
  );
end;
$$;

revoke all on function public.apply_commission_statement(uuid,jsonb)
from public, anon, authenticated;
grant execute on function public.apply_commission_statement(uuid,jsonb)
to service_role;
