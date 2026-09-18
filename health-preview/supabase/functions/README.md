# Edge Function Handoff

Prepared for the dedicated Supabase project. Nothing here is deployed yet.

## Runtime
Edge handlers use pinned `@supabase/server@1.7.0`, matching current Supabase guidance for header-based Edge Function auth.

### Authenticated user functions
- bootstrap-tenant
- create-team-invite
- accept-team-invite
- create-portal-invite
- accept-portal-invite

These use `auth: 'user'` and keep the default platform `verify_jwt = true`.

### Public functions
- public-intake
- public-booking
- public-availability

These use `auth: 'none'`, are configured with `verify_jwt = false`, and enforce a server-side hashed-IP database rate limit before privileged work.

### External webhook
- provider-webhook

This uses `auth: 'none'` / `verify_jwt = false`. It remains safe-by-default and returns 503 until the selected provider's signature verifier is implemented.

## Supabase-provided environment
The hosted runtime provides the project URL, publishable keys, secret keys, and JWKS for `@supabase/server`. Do not create a browser-visible service-role/secret-key variable.

## Application/provider secrets
Set only non-Supabase application/provider secrets, including:
- PUBLIC_ENDPOINT_SALT
- provider API keys
- provider webhook secrets
- allowed origins / provider-specific configuration

## Public endpoint enablement
`PUBLIC_INTAKE_ENABLED` and `PUBLIC_BOOKING_ENABLED` remain false until:
1. migrations/RLS apply cleanly
2. rate-limit RPC passes
3. CORS/origin configuration is correct
4. website form/booking integration is tested
5. database advisors are clean
6. live monitoring/logging is checked

## Function configuration
`supabase/config.toml` explicitly disables platform JWT verification only for public endpoints and the external provider webhook.

## Deployment order
Deploy functions only after:
- target SQL modules execute successfully
- tenant/role/storage tests pass
- database advisors are reviewed and fixed
- project Auth settings are configured
- application/provider secrets are configured
