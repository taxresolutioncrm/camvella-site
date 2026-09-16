# Deployment Runbook

## Current state
Preview branch only. Production/main is untouched.

## Before release
1. Finalize product name and domain.
2. Connect dedicated Supabase project.
3. Apply migrations in documented order.
4. Run database advisors.
5. Run T1-T11 tenant-isolation tests.
6. Connect frontend using publishable key only.
7. Configure provider secrets in trusted server/Edge Function environment.
8. Verify auth and role access.
9. Verify email, voice, SMS, fax, CMS and carrier flows.
10. Replace preview/noindex SEO configuration with production SEO package.
11. Run static QA and live workflow QA.

## Release rule
One clean production release after sandbox/backend tests pass.

## Post-release verification
- homepage
- CRM login
- each top-level CRM group
- ACA workflow
- Medicare workflow
- email/phone/SMS/fax
- client portal
- enrollment submission
- policy servicing
- renewals
- commissions
- compliance evidence
- carrier contracting
- sitemap/robots/canonical
- analytics tags
- favicon/branding
- mobile sidebar behavior

Do not call the release complete until the live checklist passes.
