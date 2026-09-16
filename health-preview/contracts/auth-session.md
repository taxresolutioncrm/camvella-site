# Auth & Session Contract

## Sign-in
Supabase Auth will be connected only after the dedicated project is selected.

## Authorization source
Authorization comes from server-controlled membership rows and/or app_metadata-derived claims refreshed from trusted backend state.

Never authorize from user_metadata.

## Required session behavior
- authenticated user resolves active memberships
- selected organization must belong to active memberships
- selected office must belong to selected organization
- role guards control privileged actions
- role or membership changes require session/token refresh before relying on JWT claims
- disabled memberships deny application access even when the Auth user still exists

## Sensitive operations
For highly privileged operations, validate current user/membership state server-side rather than trusting stale browser state.

## Logout / revocation
Account removal or access revocation must include session invalidation where required; deleting an Auth user alone is not treated as immediate token invalidation.
