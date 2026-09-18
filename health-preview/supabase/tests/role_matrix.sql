-- role_matrix.sql
-- Execute after the dedicated Supabase project exists and fixtures are loaded.
-- Replace all PLACEHOLDER UUIDs before running.
--
-- Required fixture users:
-- ADMIN_USER, MANAGER_USER, AGENT_A_USER, AGENT_B_USER, COMPLIANCE_USER, REVENUE_USER, PORTAL_USER
-- Required records:
-- ORG_A, OFFICE_A, OFFICE_B, CLIENT_AGENT_A, CLIENT_AGENT_B, ENROLLMENT_AGENT_A,
-- COMMISSION_LINE_AGENT_A, PORTAL_CLIENT, ORG_B

begin;

create temporary table role_results(
  test_name text primary key,
  expected text not null,
  actual text not null,
  result text not null
) on commit drop;

create or replace function pg_temp.result(
  p_name text,p_expected text,p_actual text,p_pass boolean
) returns void language plpgsql as $$
begin
  insert into role_results values(p_name,p_expected,p_actual,case when p_pass then 'PASS' else 'FAIL' end);
end $$;

do $$
begin
  if 'ORG_A'='ORG_A' then
    raise exception 'Replace fixture placeholders before running role_matrix.sql';
  end if;
end $$;

-- R1 assigned agent can read assigned client.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"AGENT_A_USER","role":"authenticated"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.clients where id='CLIENT_AGENT_A'::uuid;
  perform pg_temp.result('R1 agent reads assigned client','1 row',n||' rows',n=1);
end $$;

-- R2 assigned agent cannot read another agent's client.
do $$
declare n integer;
begin
  select count(*) into n from public.clients where id='CLIENT_AGENT_B'::uuid;
  perform pg_temp.result('R2 agent blocked from other agent client','0 rows',n||' rows',n=0);
end $$;

-- R3 agent cannot read a sibling office lead even in same organization.
do $$
declare n integer;
begin
  select count(*) into n from public.leads
  where organization_id='ORG_A'::uuid and office_id='OFFICE_B'::uuid;
  perform pg_temp.result('R3 agent sibling-office lead isolation','0 rows',n||' rows',n=0);
end $$;

-- R4 revenue can read commission data.
select set_config('request.jwt.claims','{"sub":"REVENUE_USER","role":"authenticated"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.commission_lines where organization_id='ORG_A'::uuid;
  perform pg_temp.result('R4 revenue reads commissions','>=1 row',n||' rows',n>=1);
end $$;

-- R5 revenue cannot read prescriptions.
do $$
declare n integer;
begin
  select count(*) into n from public.client_prescriptions where organization_id='ORG_A'::uuid;
  perform pg_temp.result('R5 revenue blocked from prescriptions','0 rows',n||' rows',n=0);
end $$;

-- R6 compliance can read enrollment evidence.
select set_config('request.jwt.claims','{"sub":"COMPLIANCE_USER","role":"authenticated"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.enrollment_evidence where enrollment_id='ENROLLMENT_AGENT_A'::uuid;
  perform pg_temp.result('R6 compliance reads enrollment evidence','>=1 row',n||' rows',n>=1);
end $$;

-- R7 compliance cannot update commission statement.
do $$
declare n integer;
begin
  update public.commission_statements set total_amount=total_amount where organization_id='ORG_A'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.result('R7 compliance blocked from commission write','0 rows updated',n||' rows updated',n=0);
end $$;

-- R8 manager can read organization-wide client book.
select set_config('request.jwt.claims','{"sub":"MANAGER_USER","role":"authenticated"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.clients where organization_id='ORG_A'::uuid;
  perform pg_temp.result('R8 manager reads org client book','>=2 rows',n||' rows',n>=2);
end $$;

-- R9 portal user gets only portal-safe profile fields through the RPC.
select set_config('request.jwt.claims','{"sub":"PORTAL_USER","role":"authenticated","aal":"aal1"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.get_my_portal_profile()
  where client_id='PORTAL_CLIENT'::uuid;
  perform pg_temp.result('R9 portal reads safe profile RPC','1 row',n||' rows',n=1);
end $$;

-- R10 portal user cannot query internal client table directly.
do $$
declare n integer;
begin
  select count(*) into n from public.clients where organization_id='ORG_A'::uuid;
  perform pg_temp.result('R10 portal blocked from client table','0 rows',n||' rows',n=0);
end $$;

-- R11 portal user cannot read internal evidence, consent, or renewal queues.
select set_config('request.jwt.claims','{"sub":"PORTAL_USER","role":"authenticated","aal":"aal1"}',true);
do $$
declare n integer;
begin
  select
    (select count(*) from public.enrollment_evidence) +
    (select count(*) from public.consent_records) +
    (select count(*) from public.renewals)
  into n;
  perform pg_temp.result('R11 portal blocked from internal workflow tables','0 rows',n||' rows',n=0);
end $$;

-- R12 cross-organization remains blocked for agency admin.
select set_config('request.jwt.claims','{"sub":"ADMIN_USER","role":"authenticated","aal":"aal2"}',true);
do $$
declare n integer;
begin
  select count(*) into n from public.clients where organization_id='ORG_B'::uuid;
  perform pg_temp.result('R12 admin cross-org isolation','0 rows',n||' rows',n=0);
end $$;

-- R13 AAL1 agency admin cannot change membership.
select set_config('request.jwt.claims','{"sub":"ADMIN_USER","role":"authenticated","aal":"aal1"}',true);
do $$
declare n integer;
begin
  update public.memberships set role=role
  where organization_id='ORG_A'::uuid and user_id='AGENT_A_USER'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.result('R13 AAL1 admin membership write blocked','0 rows updated',n||' rows updated',n=0);
end $$;

-- R14 AAL2 agency admin may update an existing member.
select set_config('request.jwt.claims','{"sub":"ADMIN_USER","role":"authenticated","aal":"aal2"}',true);
do $
declare n integer;
begin
  update public.memberships set role=role
  where organization_id='ORG_A'::uuid and user_id='AGENT_A_USER'::uuid;
  get diagnostics n=row_count;
  perform pg_temp.result('R14 AAL2 admin membership update allowed','1 row updated',n||' rows updated',n=1);
end $;

-- R15 deactivating a member disables public-facing references before the membership goes inactive.
do $
declare n integer;
begin
  update public.memberships
  set is_active=false
  where organization_id='ORG_A'::uuid and user_id='AGENT_A_USER'::uuid;

  select
    (select count(*) from public.booking_links
      where organization_id='ORG_A'::uuid and user_id='AGENT_A_USER'::uuid and is_active=true)
    +
    (select count(*) from public.scheduling_availability_rules
      where organization_id='ORG_A'::uuid and user_id='AGENT_A_USER'::uuid and is_active=true)
    +
    (select count(*) from public.public_intake_forms
      where organization_id='ORG_A'::uuid and assigned_user_id='AGENT_A_USER'::uuid)
    +
    (select count(*) from public.communication_endpoints
      where organization_id='ORG_A'::uuid and user_id='AGENT_A_USER'::uuid and status='active')
  into n;

  perform pg_temp.result(
    'R15 member deactivation public safety',
    '0 active public references',
    n||' active public references',
    n=0
  );
end $;

reset role;
select * from role_results order by test_name;
rollback;
