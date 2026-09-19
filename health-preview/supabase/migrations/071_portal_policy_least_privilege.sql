-- 071_portal_policy_least_privilege.sql
-- Client portal receives a safe policy projection rather than direct access to full policy rows.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists policies_select on public.policies;

create policy policies_select on public.policies
for select to authenticated
using (
  app_private.can_view_internal_client(client_id)
);

create or replace function public.list_my_portal_policies()
returns table(
  id uuid,
  policy_number text,
  status text,
  market public.market_type,
  effective_date date,
  renewal_date date,
  premium_amount numeric(12,2),
  carrier_name text,
  product_name text
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    p.id,
    p.policy_number,
    p.status,
    c.market,
    p.effective_date,
    p.renewal_date,
    p.premium_amount,
    cr.name as carrier_name,
    cp.product_name
  from public.client_portal_accounts a
  join public.clients c
    on c.id=a.client_id
   and c.organization_id=a.organization_id
  join public.policies p
    on p.client_id=c.id
   and p.organization_id=c.organization_id
  join public.carriers cr
    on cr.id=p.carrier_id
   and cr.organization_id=p.organization_id
  left join public.carrier_products cp
    on cp.id=p.carrier_product_id
   and cp.organization_id=p.organization_id
  where a.user_id=(select auth.uid())
    and a.status='active'
  order by p.effective_date desc,p.created_at desc
$$;

revoke all on function public.list_my_portal_policies()
from public, anon;
grant execute on function public.list_my_portal_policies()
to authenticated;
