-- 019_domain_relationship_guards.sql
-- Rejects same-tenant but internally inconsistent relationships.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_enrollment_relationships()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  product_carrier uuid;
begin
  if new.carrier_product_id is not null then
    select carrier_id into product_carrier
    from public.carrier_products
    where id=new.carrier_product_id;

    if new.carrier_id is null or product_carrier is distinct from new.carrier_id then
      raise exception 'enrollment carrier product does not belong to selected carrier';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function app_private.guard_enrollment_relationships() from public, anon, authenticated;
create trigger enrollment_relationship_guard
before insert or update on public.enrollments
for each row execute function app_private.guard_enrollment_relationships();

create or replace function app_private.guard_policy_relationships()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  enrollment_client uuid;
  product_carrier uuid;
begin
  if new.enrollment_id is not null then
    select client_id into enrollment_client from public.enrollments where id=new.enrollment_id;
    if enrollment_client is distinct from new.client_id then
      raise exception 'policy enrollment belongs to a different client';
    end if;
  end if;

  if new.carrier_product_id is not null then
    select carrier_id into product_carrier from public.carrier_products where id=new.carrier_product_id;
    if product_carrier is distinct from new.carrier_id then
      raise exception 'policy carrier product does not belong to selected carrier';
    end if;
  end if;

  return new;
end;
$$;
revoke all on function app_private.guard_policy_relationships() from public, anon, authenticated;
create trigger policy_relationship_guard
before insert or update on public.policies
for each row execute function app_private.guard_policy_relationships();

create or replace function app_private.guard_client_parent(
  parent_table text,
  parent_id uuid,
  expected_client uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_client uuid;
begin
  if parent_id is null then return; end if;
  execute format('select client_id from public.%I where id=$1',parent_table)
  into parent_client using parent_id;
  if parent_client is distinct from expected_client then
    raise exception 'parent % belongs to a different client',parent_table;
  end if;
end;
$$;
revoke all on function app_private.guard_client_parent(text,uuid,uuid) from public, anon, authenticated;

create or replace function app_private.guard_client_linked_rows()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name='service_requests' then
    perform app_private.guard_client_parent('policies',new.policy_id,new.client_id);
  elsif tg_table_name='renewals' then
    perform app_private.guard_client_parent('policies',new.policy_id,new.client_id);
  elsif tg_table_name='plan_comparisons' then
    perform app_private.guard_client_parent('enrollments',new.enrollment_id,new.client_id);
  elsif tg_table_name='documents' then
    perform app_private.guard_client_parent('enrollments',new.enrollment_id,new.client_id);
  elsif tg_table_name='consent_records' then
    perform app_private.guard_client_parent('enrollments',new.enrollment_id,new.client_id);
    if new.artifact_document_id is not null then
      perform app_private.guard_client_parent('documents',new.artifact_document_id,new.client_id);
    end if;
  end if;
  return new;
end;
$$;
revoke all on function app_private.guard_client_linked_rows() from public, anon, authenticated;

create trigger service_request_client_guard
before insert or update on public.service_requests
for each row execute function app_private.guard_client_linked_rows();
create trigger renewal_client_guard
before insert or update on public.renewals
for each row execute function app_private.guard_client_linked_rows();
create trigger plan_comparison_client_guard
before insert or update on public.plan_comparisons
for each row execute function app_private.guard_client_linked_rows();
create trigger document_client_guard
before insert or update on public.documents
for each row execute function app_private.guard_client_linked_rows();
create trigger consent_client_guard
before insert or update on public.consent_records
for each row execute function app_private.guard_client_linked_rows();

create or replace function app_private.guard_communication_thread_alignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  thread_client uuid;
  thread_lead uuid;
begin
  select client_id,lead_id into thread_client,thread_lead
  from public.communication_threads
  where id=new.thread_id;

  if new.client_id is not null and thread_client is not null and new.client_id<>thread_client then
    raise exception 'communication client does not match thread client';
  end if;
  if new.lead_id is not null and thread_lead is not null and new.lead_id<>thread_lead then
    raise exception 'communication lead does not match thread lead';
  end if;
  return new;
end;
$$;
revoke all on function app_private.guard_communication_thread_alignment() from public, anon, authenticated;
create trigger communication_thread_alignment_guard
before insert or update on public.communications
for each row execute function app_private.guard_communication_thread_alignment();
