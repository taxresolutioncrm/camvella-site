-- 090_secret_reference_column_boundary.sql
-- Sensitive token hashes and provider secret references are never returned through the browser Data API.
-- Provider secret references are also server-only mutation fields.
-- DO NOT APPLY until the dedicated Supabase project is selected.

revoke select on public.team_invitations from authenticated;
grant select (
  id,
  organization_id,
  office_id,
  email,
  role,
  invited_by,
  expires_at,
  accepted_at,
  created_at
) on public.team_invitations to authenticated;

revoke select on public.portal_invitations from authenticated;
grant select (
  id,
  organization_id,
  client_id,
  email,
  expires_at,
  accepted_at,
  created_by,
  created_at
) on public.portal_invitations to authenticated;

revoke select on public.provider_connections from authenticated;
grant select (
  id,
  organization_id,
  office_id,
  provider_type,
  provider_name,
  external_account_id,
  status,
  config_public,
  created_at,
  updated_at
) on public.provider_connections to authenticated;

revoke insert,update on public.provider_connections from authenticated;
grant insert (
  organization_id,
  office_id,
  provider_type,
  provider_name,
  external_account_id,
  status,
  config_public
) on public.provider_connections to authenticated;
grant update (
  office_id,
  provider_type,
  provider_name,
  external_account_id,
  status,
  config_public,
  updated_at
) on public.provider_connections to authenticated;

revoke select on public.provider_event_ledger from authenticated;
grant select (
  id,
  organization_id,
  provider,
  provider_event_id,
  event_type,
  payload_version,
  signature_valid,
  received_at,
  processed_at,
  processing_status,
  normalized_entity_type,
  normalized_entity_id
) on public.provider_event_ledger to authenticated;
