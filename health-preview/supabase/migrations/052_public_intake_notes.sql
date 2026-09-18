-- 052_public_intake_notes.sql
-- Persists optional public-intake context instead of discarding it.
-- DO NOT APPLY until the dedicated Supabase project is selected.

alter table public.leads
add column notes text;

drop function if exists public.submit_public_intake(
  text,text,text,text,text,public.market_type
);

create function public.submit_public_intake(
  p_slug text,
  p_first_name text,
  p_last_name text,
  p_email text,
  p_phone text,
  p_market public.market_type default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  form_row public.public_intake_forms%rowtype;
  lead_id uuid;
  chosen_market public.market_type;
begin
  select * into form_row
  from public.public_intake_forms
  where slug=lower(trim(p_slug))
    and is_active=true
  limit 1;

  if form_row.id is null then
    raise exception 'intake form not found';
  end if;

  if length(trim(coalesce(p_first_name,'')))<1
     or length(trim(coalesce(p_last_name,'')))<1 then
    raise exception 'first and last name are required';
  end if;

  if nullif(trim(coalesce(p_email,'')),'') is null
     and nullif(trim(coalesce(p_phone,'')),'') is null then
    raise exception 'email or phone is required';
  end if;

  if form_row.default_market is not null
     and p_market is not null
     and p_market<>form_row.default_market then
    raise exception 'market does not match intake form';
  end if;

  chosen_market:=coalesce(form_row.default_market,p_market);
  if chosen_market is null then
    raise exception 'market is required';
  end if;

  insert into public.leads(
    organization_id,office_id,assigned_user_id,
    first_name,last_name,email,phone,market,source,stage,notes
  ) values (
    form_row.organization_id,form_row.office_id,form_row.assigned_user_id,
    trim(p_first_name),trim(p_last_name),nullif(trim(p_email),''),
    nullif(trim(p_phone),''),chosen_market,form_row.source,'new',
    nullif(left(trim(coalesce(p_notes,'')),4000),'')
  )
  returning id into lead_id;

  return jsonb_build_object('lead_id',lead_id);
end;
$$;

revoke all on function public.submit_public_intake(
  text,text,text,text,text,public.market_type,text
) from public, anon, authenticated;

grant execute on function public.submit_public_intake(
  text,text,text,text,text,public.market_type,text
) to service_role;
