-- 056_commission_storage_path_alignment.sql
-- Commission statement objects are keyed by statement ID so Storage RLS can authorize before parsing.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create or replace function app_private.guard_commission_statement_storage_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  path_org uuid;
  path_statement uuid;
begin
  if new.storage_path is null then
    return new;
  end if;

  begin
    path_org:=split_part(new.storage_path,'/',1)::uuid;
    path_statement:=split_part(new.storage_path,'/',3)::uuid;
  exception when others then
    raise exception 'invalid commission statement storage path';
  end;

  if path_org<>new.organization_id or path_statement<>new.id then
    raise exception 'commission statement storage path does not match organization/statement';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_commission_statement_storage_path()
from public, anon, authenticated;
