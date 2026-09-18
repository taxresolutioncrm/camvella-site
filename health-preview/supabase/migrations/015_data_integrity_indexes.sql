-- 015_data_integrity_indexes.sql
-- Idempotency, uniqueness and query-shape indexes.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create unique index if not exists communications_provider_message_uq
on public.communications(provider,provider_message_id)
where provider_message_id is not null;

create unique index if not exists policies_carrier_policy_uq
on public.policies(organization_id,carrier_id,policy_number)
where policy_number is not null;

create unique index if not exists carrier_products_external_uq
on public.carrier_products(organization_id,carrier_id,external_product_id)
where external_product_id is not null;

create unique index if not exists commission_statement_source_uq
on public.commission_statements(organization_id,carrier_id,source_filename,statement_period_start,statement_period_end)
where source_filename is not null;

create index if not exists leads_stage_idx
on public.leads(organization_id,stage,created_at desc);

create index if not exists clients_market_idx
on public.clients(organization_id,market,updated_at desc);

create index if not exists enrollments_market_status_idx
on public.enrollments(organization_id,market,lifecycle_status,updated_at desc);

create index if not exists policies_renewal_idx
on public.policies(organization_id,renewal_date)
where status='active';

create index if not exists service_requests_queue_idx
on public.service_requests(organization_id,status,priority,sla_due_at);

create index if not exists communications_unread_idx
on public.communications(organization_id,read_at,created_at desc);

create index if not exists renewals_risk_idx
on public.renewals(organization_id,risk_level,review_window_start);

create index if not exists commission_lines_match_idx
on public.commission_lines(organization_id,match_status,statement_id);

create index if not exists commission_exceptions_queue_idx
on public.commission_exceptions(organization_id,status,created_at);

create index if not exists audit_log_actor_idx
on public.audit_log(organization_id,actor_user_id,created_at desc);

create index if not exists provider_event_dedupe_lookup_idx
on public.provider_event_ledger(provider,provider_event_id);

create index if not exists team_invitations_expiry_idx
on public.team_invitations(organization_id,expires_at)
where accepted_at is null;

create index if not exists portal_invitations_expiry_idx
on public.portal_invitations(organization_id,expires_at)
where accepted_at is null;

create index if not exists client_portal_accounts_client_idx
on public.client_portal_accounts(organization_id,client_id,status);
