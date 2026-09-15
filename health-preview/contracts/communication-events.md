# Communication Event Contract

## Unified communication event
- id
- organization_id
- office_id
- thread_id
- channel
- direction
- client_id nullable
- lead_id nullable
- user_id nullable
- provider
- provider_message_id nullable
- provider_thread_id nullable
- provider_status
- from_address
- to_address
- subject nullable
- body_text nullable
- body_preview nullable
- attachment_count
- recording_ref nullable
- fax_pages nullable
- voicemail_duration_seconds nullable
- created_at
- delivered_at nullable
- read_at nullable

## Channel values
- email
- phone
- sms
- fax
- voicemail
- portal

## Direction values
- inbound
- outbound

## Provider status examples
- queued
- sent
- delivered
- failed
- received
- answered
- missed
- completed

## Inbound event normalization
Provider webhook/event -> verify signature -> resolve organization/office -> resolve thread/contact -> persist raw provider reference -> persist normalized communication event -> create audit entry -> notify assigned user if required.

## Outbound flow
User action -> authorization check -> create pending event -> provider adapter -> persist provider ID/status -> update thread summary -> audit privileged action.
