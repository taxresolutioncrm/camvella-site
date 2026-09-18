-- 046_import_storage_role_alignment.sql
-- Bulk import staging is management-only; revenue uses the dedicated commission bucket.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.can_access_import_object(
  p_name text,
  p_write boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  org_id uuid;
begin
  begin
    org_id:=split_part(p_name,'/',1)::uuid;
  exception when others then
    return false;
  end;

  return app_private.has_org_role(
    org_id,
    array['agency_admin','manager']::public.member_role[]
  );
end;
$$;

revoke all on function app_private.can_access_import_object(text,boolean)
from public, anon;
grant execute on function app_private.can_access_import_object(text,boolean)
to authenticated;
