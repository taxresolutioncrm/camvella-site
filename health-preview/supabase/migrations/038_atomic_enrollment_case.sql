-- 038_atomic_enrollment_case.sql
-- Transactional enrollment creation + internal workflow evidence initialization.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function public.create_enrollment_case(
  p_client_id uuid,
  p_assigned_user_id uuid,
  p_market public.market_type,
  p_enrollment_type text default null,
  p_household_size integer default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public, auth
as $$
declare
  c public.clients%rowtype;
  enrollment_id uuid;
begin
  select * into c
  from public.clients
  where id=p_client_id;

  if c.id is null then
    raise exception 'client not found or not accessible';
  end if;

  if c.market is distinct from p_market then
    raise exception 'client market does not match enrollment market';
  end if;

  insert into public.enrollments(
    organization_id,
    office_id,
    client_id,
    assigned_user_id,
    market,
    enrollment_type,
    lifecycle_status
  ) values (
    c.organization_id,
    c.office_id,
    c.id,
    p_assigned_user_id,
    p_market,
    nullif(trim(p_enrollment_type),''),
    'draft'
  )
  returning id into enrollment_id;

  if p_market='aca' and p_household_size is not null then
    if p_household_size<1 then
      raise exception 'household size must be at least 1';
    end if;

    insert into public.households(
      organization_id,
      client_id,
      household_size
    ) values (
      c.organization_id,
      c.id,
      p_household_size
    );
  end if;

  -- Internal workflow gates. These are operational evidence categories,
  -- not representations of jurisdiction-specific legal requirements.
  insert into public.enrollment_evidence(
    organization_id,
    enrollment_id,
    evidence_type,
    status,
    required_for_submission,
    created_by
  )
  select
    c.organization_id,
    enrollment_id,
    x.evidence_type,
    'pending',
    true,
    auth.uid()
  from (
    values
      ('client_authorization'),
      ('eligibility_review'),
      ('selection_review'),
      ('submission_review')
  ) as x(evidence_type);

  return jsonb_build_object(
    'enrollment_id',enrollment_id,
    'client_id',c.id,
    'market',p_market
  );
end;
$$;

revoke all on function public.create_enrollment_case(uuid,uuid,public.market_type,text,integer)
from public, anon;
grant execute on function public.create_enrollment_case(uuid,uuid,public.market_type,text,integer)
to authenticated;
