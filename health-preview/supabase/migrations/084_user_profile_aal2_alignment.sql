-- 084_user_profile_aal2_alignment.sql
-- Team profile visibility follows the same tenant/MFA boundary as the rest of the agency workspace.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists user_profiles_select on public.user_profiles;

create policy user_profiles_select on public.user_profiles
for select to authenticated
using (
  user_id=(select auth.uid())
  or exists(
    select 1
    from public.memberships mine
    join public.memberships theirs
      on theirs.organization_id=mine.organization_id
    where mine.user_id=(select auth.uid())
      and mine.is_active=true
      and mine.organization_id in (select app_private.current_org_ids())
      and theirs.user_id=user_profiles.user_id
      and theirs.is_active=true
  )
);
