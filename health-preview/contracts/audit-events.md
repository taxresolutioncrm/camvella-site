# Audit Event Contract

Every privileged or state-changing operation should generate an audit event.

## Audit event
- id
- organization_id
- office_id nullable
- actor_user_id nullable
- actor_type
- action
- entity_type
- entity_id
- before_json nullable
- after_json nullable
- metadata_json nullable
- ip_hash nullable
- created_at

## Required audit actions
- client.created
- client.updated
- lead.stage_changed
- appointment.created
- enrollment.status_changed
- enrollment.submitted
- evidence.added
- consent.created
- policy.created
- policy.updated
- service_request.created
- service_request.resolved
- communication.sent
- communication.received
- document.uploaded
- commission_statement.imported
- commission_exception.created
- commission_exception.resolved
- carrier_contract.updated
- user.role_changed
- settings.updated

## Integrity expectations
- append-only application behavior
- no client-side delete path
- tenant-scoped access
- privileged export audited
