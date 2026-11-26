# Camvella website content, image, and SEO audit — 2026-11-25

Status: **STAGED ONLY / NOT DEPLOYED / NOT BUILD-VERIFIED**

## Scope and findings

- Reviewed site repository tree (125 entries), SEO build scripts, homepage, product, pricing, demo, about, security, accounting, other feature and comparison/solution routes, plus curated `CommunityPhoto` photo mapping.
- **Confirmed exact editorial-photo repeat:** `src/pages/about.astro` and `src/pages/compare/index.astro` both rendered `CommunityPhoto image="streets"`. Changed Compare to the previously unused `operations` image key. URLs and photo IDs are different. Source uniqueness check now compares Unsplash photo IDs independent of transformation parameters.
- **Prevent recurrence:** added `scripts/audit-editorial-images.mjs`; `npm run build` now runs this photo-ID gate before Astro/site SEO validation. This detects duplicated editorial images across pages and unknown image-key usage. It is not a perceptual similarity algorithm.
- **Marketing accuracy:** updated `/security` to discuss verified authoritative financial role/permission and journal primitive restrictions, while explicitly stating that end-to-end accounting verification remains outstanding. Updated `/features/hoa-accounting` with those controls, honest banking/reconciliation rollout status, improved metadata, and links to security + reserve accounting guide.
- **SEO:** existing build runs Astro, fresh sitemap generation, and SEO validation. Expanded checks to *report* duplicate indexable page titles, descriptions, and broken same-origin links; new checks are warnings until a full build baseline is observed to avoid unexpected Cloudflare failure. Existing canonical/robots/schema/sitemap/hub checks still block a bad build.
- Public site search results confirmed indexing for core HOA, accounting, security, Florida and comparisons; publication/search indexing is **not evidence** that draft updates are already live. The canonical/robots sitemap endpoints were not directly retrievable with available web fetch, so their live HTTP status remains unverified.

## Required release verification (not yet performed)

1. Execute `npm ci && npm run audit:images && npm run build` locally/sandbox (not GitHub Actions); inspect warnings, repair genuine broken links/duplicate titles.
2. Visually compare homepage, About, Compare, Product, Pricing, Security, Accounting and responsive mobile views to rule out *perceptually* similar photos with different asset IDs.
3. Inspect generated `dist/sitemap.xml`, canonical metadata, structured data, internal navigation, indexable page count, robots.txt and HTTP redirects in Cloudflare preview.
4. Check GA4, Clarity, Bing and Search Console verification after deployment. Do not claim ranking improvement without observed analytics.
5. Complete the independent CRM functional/security audit. Permission grants 0104–0110 were verified live, but accounting E2E testing and direct finance table write hardening remain unresolved. Do not claim the CRM audit is complete on the website.

No GitHub Actions minute usage. No merge, release, Cloudflare production deployment, or backend changes.
