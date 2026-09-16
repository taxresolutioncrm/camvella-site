# Webhook / Provider Event Contract

## Common inbound envelope
- provider
- event_type
- provider_event_id
- received_at
- signature_valid
- organization_hint
- office_hint
- payload_version
- raw_payload_ref

## Processing sequence
1. Verify provider signature.
2. Reject replayed provider_event_id.
3. Resolve organization and office using server-side mapping.
4. Normalize provider payload to internal communication/carrier event.
5. Persist provider IDs and status.
6. Update linked thread/client/enrollment if applicable.
7. Append audit event.
8. Queue user notification.
9. Return provider-safe acknowledgement.

## Idempotency
provider + provider_event_id must be unique in the server-side ingestion ledger.

## Secrets
Webhook secrets and provider API keys must never be exposed to the browser. Use Edge Functions or another trusted server runtime.
