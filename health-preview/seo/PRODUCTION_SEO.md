# Production SEO Handoff

## Identity blockers
- Final product name
- Final production domain

Do not ship placeholder canonicals.

## Required production head
- unique title
- unique meta description
- canonical URL
- Open Graph title/description/url/type
- Twitter card metadata
- Organization schema
- SoftwareApplication schema on product pages
- BreadcrumbList on nested content
- Article schema on editorial resources when applicable

## Indexing
- Public marketing pages: index,follow
- CRM/app routes: noindex,nofollow
- Auth/account pages: noindex,nofollow
- Internal preview/staging: noindex,nofollow

## Content architecture
### Core commercial
- /
- /aca-crm
- /medicare-crm
- /health-insurance-agency-crm
- /pricing
- /security

### Feature clusters
- /features/lead-management
- /features/enrollment-management
- /features/plan-comparison
- /features/compliance
- /features/renewals
- /features/policy-servicing
- /features/client-portal
- /features/communications
- /features/commission-reconciliation
- /features/carrier-contracting
- /features/reporting

### Education
- /resources/aca-open-enrollment-crm
- /resources/aca-special-enrollment-period
- /resources/medicare-aep-crm
- /resources/medicare-oep-crm
- /resources/medicare-sep-crm
- /resources/health-insurance-crm-buyers-guide
- /resources/commission-chargebacks
- /resources/call-recording-workflows
- /resources/insurance-client-portal

## State architecture
Only publish a state page when it contains substantive, unique state-specific operational material. Do not mass-generate thin state doorway pages.

## Analytics handoff
Add GA4, Clarity and Search Console only after final domain is selected.
