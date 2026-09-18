-- 041_policy_event_and_campaign_role_alignment.sql
-- Tightens policy-event and campaign-member visibility to the assigned client model.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop policy if exists policy_events_select on public.policy_events;
drop policy if exists policy_events_insert on public.policy_events;

create policy policy_events_select on public.policy_events
for select to authenticated
using (
  exists(
    select 1
    from public.policies p
    where p.id=policy_id
      and app_private.can_view_client(p.client_id)
  )
);

create policy policy_events_insert on public.policy_events
for insert to authenticated
with check (
  exists(
    select 1
    from public.policies p
    where p.id=policy_id
      and (
        app_private.can_manage_client(p.client_id)
        or app_private.has_org_role(p.organization_id,array['compliance']::public.member_role[])
      )
  )
);

drop policy if exists outreach_campaign_members_select on public.outreach_campaign_members;

create policy outreach_campaign_members_select on public.outreach_campaign_members
for select to authenticated
using (
  app_private.has_org_role(organization_id,array['agency_admin','manager']::public.member_role[])
  or (
    app_private.has_org_role(organization_id,array['agent']::public.member_role[])
    and app_private.can_manage_client(client_id)
  )
);
