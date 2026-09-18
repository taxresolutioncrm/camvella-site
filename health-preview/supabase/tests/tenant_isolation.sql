-- tenant_isolation.sql
-- Execute only after the dedicated project exists and two authenticated fixture users
-- have been created and attached to separate organizations.
--
-- Replace the fixture constants below before execution:
-- USER_A, USER_B, ORG_A, ORG_B, OFFICE_B.
--
-- This file intentionally uses request.jwt.claims to exercise auth.uid()-based RLS.

begin;

create temporary table isolation_results (
  test_name text primary key,
  expected text not null,
  actual text not null,
  result text not null
) on commit drop;

create or replace function pg_temp.record_result(
  p_name text, p_expected text, p_actual text, p_pass boolean
) returns void language plpgsql as $$
begin
  insert into isolation_results values
    (p_name,p_expected,p_actual,case when p_pass then 'PASS' else 'FAIL' end);
end $$;

-- ===== FIXTURE CONSTANTS =====
do $$
begin
  if 'USER_A' = 'USER_A' then
    raise exception 'Replace USER_A / USER_B / ORG_A / ORG_B / OFFICE_B fixture UUIDs before running tenant isolation tests';
  end if;
end $$;

-- The blocks below are ready once constants are replaced.

-- T1: org A cannot SELECT org B client
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"USER_A","role":"authenticated"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.clients where organization_id='ORG_B'::uuid;
  perform pg_temp.record_result('T1 cross-org SELECT client','0 rows',n||' rows',n=0);
end $$;

-- T2: org A cannot INSERT org B lead
do $$
declare blocked boolean:=false;
begin
  begin
    insert into public.leads(organization_id,first_name,last_name,market)
    values('ORG_B'::uuid,'Isolation','Probe','aca');
  exception when others then blocked:=true;
  end;
  perform pg_temp.record_result('T2 cross-org INSERT lead','Blocked by RLS',case when blocked then 'Blocked by RLS' else 'Insert succeeded' end,blocked);
end $$;

-- T3: org A cannot UPDATE org B client
do $$
declare n integer;
begin
  update public.clients set first_name=first_name where organization_id='ORG_B'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.record_result('T3 cross-org UPDATE client','0 rows updated',n||' rows updated',n=0);
end $$;

-- T4: org A cannot DELETE org B document
do $$
declare n integer;
begin
  delete from public.documents where organization_id='ORG_B'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.record_result('T4 cross-org DELETE document','0 rows deleted',n||' rows deleted',n=0);
end $$;

-- T5: non-admin cannot change membership
-- Requires USER_A membership role=agent in ORG_A.
do $$
declare blocked boolean:=false;
begin
  begin
    update public.memberships set role='manager'
    where organization_id='ORG_A'::uuid and user_id='USER_A'::uuid;
  exception when others then blocked:=true;
  end;
  perform pg_temp.record_result('T5 agent changes membership','Blocked / 0 rows','Attempt completed; inspect row count separately',blocked or not exists(
    select 1 from public.memberships where organization_id='ORG_A'::uuid and user_id='USER_A'::uuid and role='manager'
  ));
end $$;

-- T6: revenue role cannot advance enrollment to submitted/active.
-- Run with a USER_A fixture whose ORG_A membership role is revenue.
do $$
declare n integer;
begin
  update public.enrollments set lifecycle_status='submitted'
  where organization_id='ORG_A'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.record_result('T6 revenue submits enrollment','0 rows updated',n||' rows updated',n=0);
end $$;

-- T7: compliance role cannot alter commission statement.
-- Run with USER_A fixture role=compliance.
do $$
declare n integer;
begin
  update public.commission_statements set total_amount=total_amount
  where organization_id='ORG_A'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.record_result('T7 compliance alters commission statement','0 rows updated',n||' rows updated',n=0);
end $$;

-- T8: assigned agent cannot read sibling-office records.
-- Requires USER_A role=agent in ORG_A and an OFFICE_B fixture populated with at least one lead.
do $$
declare n integer;
begin
  select count(*) into n
  from public.leads
  where organization_id='ORG_A'::uuid
    and office_id='OFFICE_B'::uuid;
  perform pg_temp.record_result(
    'T8 sibling-office isolation',
    '0 rows',
    n||' rows',
    n=0
  );
end $$;

-- T9: an allowed user mutation produces an audit row.
-- Requires a USER_A-assigned ORG_A client fixture.
do $$
declare
  target_id uuid;
  before_count integer;
  after_count integer;
begin
  select id into target_id
  from public.clients
  where organization_id='ORG_A'::uuid
    and assigned_user_id='USER_A'::uuid
  limit 1;

  if target_id is null then
    perform pg_temp.record_result('T9 mutation audit','Fixture client required','Fixture missing',false);
  else
    select count(*) into before_count
    from public.audit_log
    where organization_id='ORG_A'::uuid
      and entity_type='clients'
      and entity_id=target_id;

    update public.clients
    set first_name=first_name
    where id=target_id;

    select count(*) into after_count
    from public.audit_log
    where organization_id='ORG_A'::uuid
      and entity_type='clients'
      and entity_id=target_id;

    perform pg_temp.record_result(
      'T9 mutation audit',
      'Audit count increases',
      before_count||' -> '||after_count,
      after_count>before_count
    );
  end if;
end $$;

-- T10: views use invoker rights and cannot expose ORG_B.
do $$
declare n integer;
begin
  select count(*) into n from public.v_open_enrollment_queue where organization_id='ORG_B'::uuid;
  perform pg_temp.record_result('T10 security_invoker view isolation','0 rows',n||' rows',n=0);
end $$;

-- T11 is intentionally not faked in SQL.
-- Storage authorization must be exercised through the Storage API so upload/read/update/delete
-- behavior is tested exactly as the application will call it.
insert into isolation_results(test_name,expected,actual,result)
values(
  'T11 storage cross-org isolation',
  'Storage API matrix passes',
  'Run STORAGE_TEST_MATRIX.md after buckets are connected',
  'MANUAL'
);

reset role;

select * from isolation_results order by test_name;
rollback;
