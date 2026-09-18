# Edge Function Handoff

These functions are prepared but are not deployed anywhere.

## Authenticated browser-facing functions
- bootstrap-tenant
- create-team-invite
- accept-team-invite
- create-portal-invite
- accept-portal-invite

They manually validate the user's bearer token through the trusted server client before calling server-only RPCs.

## Provider webhook
- provider-webhook

This endpoint is intentionally safe-by-default and rejects events until provider-specific signature verification is implemented.

When the actual provider is selected:
1. Configure the provider webhook secret in Supabase project secrets.
2. Implement the provider-specific verifier.
3. Resolve organization/office using server-controlled mappings.
4. Keep provider + provider_event_id idempotent.
5. Normalize into the internal event model.
6. Append audit history.
7. Add replay/failure tests before enabling the endpoint.

## Secrets
- Browser: project URL + publishable key only.
- Edge Functions: APP_SUPABASE_SECRET_KEY and provider secrets.
- Never return or expose the server secret to browser code.

## CORS
Set APP_ALLOWED_ORIGINS to the production app origin. The shared helper does not wildcard browser origins.

## Deployment order
Deploy functions only after:
- schema migrations apply cleanly
- RLS/isolation tests pass
- database advisors are reviewed
- required project secrets are configured
