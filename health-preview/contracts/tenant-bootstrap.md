# Tenant Bootstrap Contract

Creating the first organization/admin membership is a trusted-server operation.

## First-account flow
1. User signs up / authenticates.
2. Trusted server or Edge Function validates the onboarding request.
3. Server creates organization.
4. Server creates office.
5. Server creates membership with role `agency_admin`.
6. Server creates user profile and notification defaults.
7. Client refreshes session/application context.
8. All subsequent operations use normal RLS policies.

## Team invite flow
1. Admin creates invitation through a trusted action.
2. Store only a hash of the invitation token.
3. Send the raw token to the invitee by email.
4. Invitee authenticates.
5. Trusted accept-invite action validates token hash, expiry, and email.
6. Create membership.
7. Mark invitation accepted.
8. Append audit event.

## Client portal invite flow
Use the same token-hash pattern. Raw invitation tokens are never stored.

## Security
No browser-side code may create its own agency-admin membership.