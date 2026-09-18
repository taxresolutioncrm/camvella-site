# Deployment Runbook

## Current state
Isolated preview branch only. Production/main is untouched.

## Pre-production sequence
1. Finalize product name/domain.
2. Select dedicated Supabase target.
3. Execute and test the ordered SQL modules.
4. Run role/tenant/office/Storage matrices.
5. Run database advisors and fix findings.
6. Generate one clean timestamped migration from the green target schema.
7. Configure Auth/MFA/redirects.
8. Deploy current Edge Functions using supabase/config.toml.
9. Connect browser runtime using project URL + publishable key only.
10. Connect email, voice, SMS, fax, Marketplace and carrier providers one at a time.
11. Replace preview/noindex SEO config with production canonicals/robots/sitemap.
12. Run full sandbox/backend workflow QA.

## Production rule
One clean production release after the sandbox/backend gate is green.

## Live verification
- homepage + public lead capture
- public availability/booking
- CRM login / password recovery / MFA
- tenant/workspace selection
- each top-level CRM group
- ACA workflow
- Medicare workflow
- email / phone / SMS / fax / voicemail
- client portal
- enrollment evidence/submission
- policy servicing
- renewals
- commissions
- compliance evidence
- carrier contracting
- global search / client activity
- sitemap / robots / canonicals
- analytics / favicon / branding
- mobile + collapsible sidebar behavior

Do not call the release complete until live verification passes.
