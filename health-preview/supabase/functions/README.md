# Edge Function Handoff

Prepared for the dedicated Supabase project. Nothing here is deployed yet.

## Runtime
All Edge handlers use pinned `@supabase/server@1.7.0`.

### Authenticated user functions
- bootstrap-tenant
- create-team-invite
- accept-team-invite
- create-portal-invite
- accept-portal-invite
- send-communication
- process-import
- process-commission-statement

These use `auth: 'user'` and retain platform JWT verification.

### Public functions
- public-intake
- public-booking
- public-availability

These use `auth: 'none'`, are configured with `verify_jwt = false`, and rely on trusted server RPCs plus hashed-IP database rate limiting. Intake/booking also include honeypot handling.

### External webhook
- provider-webhook

This uses `auth: 'none'` / `verify_jwt = false`. It remains disabled-by-design until a provider-specific signature verifier is implemented.

## Supabase-provided environment
The hosted runtime provides project URL, publishable keys, secret keys and JWKS for the server SDK. Browser code must never receive a service-role/secret key.

## Application/provider secrets
Configure only target-specific application/provider values:
- APP_ALLOWED_ORIGIN
- PUBLIC_ENDPOINT_SALT
- PUBLIC_INTAKE_ENABLED
- PUBLIC_BOOKING_ENABLED
- provider API keys
- provider webhook secrets

## Safety gates
Public intake/booking remain disabled until:
1. all SQL modules execute successfully
2. RLS/Storage/AAL2 tests pass
3. rate-limit RPC works
4. CORS/origin is correct
5. public form/booking flow passes
6. database advisors are clean/reviewed
7. monitoring/logging is verified

The provider webhook remains disabled until its selected provider signature verifier is implemented and tested.

## Deployment order
1. Apply/test the target SQL stack.
2. Configure Auth/MFA/redirects.
3. Configure secrets/origins.
4. Deploy authenticated functions.
5. Test bootstrap/invites/portal/communication/import/commission functions.
6. Deploy public functions with intake/booking flags still false.
7. Verify availability/rate limiting.
8. Enable intake/booking only after HTTP acceptance tests pass.
9. Enable provider webhook only after signature verification is implemented.
