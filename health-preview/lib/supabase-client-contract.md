# Browser Client Contract

## Required runtime values
- Supabase project URL
- Supabase publishable key

Those values are public client configuration and are safe only because RLS/grants enforce authorization.

## Never in browser
- secret key
- service-role key
- provider credentials
- webhook secrets
- raw invitation token hashes

## Initialization
1. Create Supabase browser client.
2. Resolve current Auth user.
3. Load active memberships.
4. Choose an organization/workspace the user actually belongs to.
5. Construct SupabaseDriver with that organization ID.
6. Let RLS remain authoritative even when the UI hides actions.

## Server actions
Use Edge Functions for:
- first tenant bootstrap
- team invite creation/acceptance
- client portal invite creation/acceptance
- provider webhooks
- provider secret operations
- future privileged integrations

The UI must not duplicate server authorization logic as a security boundary.
