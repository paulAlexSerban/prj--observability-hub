# ADR-003: Use Cloudflare Web Analytics as the $0 visitor-analytics bridge (before Umami)

## Status
Accepted

## Date
2026-08-12

## Context

Phase 0 answers CDN questions (CloudWatch + access logs). It does **not** answer "who is reading the blog as a person." That was parked in Phase 2 (Umami on a VPS), which is gated on Phase 1 (rent a box).

Visitor analytics does not actually need a VPS. Cloudflare Web Analytics is a cookie-less JS beacon, free, and works on sites that are **not** proxied through Cloudflare (manual snippet). The four surfaces sit on CloudFront, so automatic HTML injection is unavailable — the snippet has to live in the apps.

The original napkin listed Cloudflare Web Analytics next to Umami/Plausible. The first cut of the plan treated it as "still a third party" and deferred all page analytics to self-hosted Umami. That delay is the wrong trade: it leaves a real product question unanswered until Lightsail exists, for a purity goal that Phase 0 already violated (AWS has the IPs).

## Decision

Add **Cloudflare Web Analytics now**, as **Phase 0b**, in parallel with Phase 0:

- One Web Analytics site (token) per production hostname
- Manual JS snippet in each app's layout / `index.html`
- Tokens only on **production** builds — local, DEV/Pages, TEST, and STAGE stay dark
- Umami (Phase 2) remains the self-hosted, data-ownership path; it is not cancelled
- Phase 3 (`web-vitals` → Umami) is **revisited**: Cloudflare already reports LCP / INP / CLS. Do not dual-instrument CWV until there is a reason to own the histograms

## Rationale

- **Same $0 / no-VPS constraint as Phase 0.** The beacon is a static script tag. No box, no Postgres, no Traefik.
- **Unblocks a question Phase 0 cannot answer.** Access-log IPs are not visitors. Cloudflare's dashboard is "browsers that ran JS."
- **Cookie-less is the product requirement.** Cloudflare does not set cookies or use `localStorage` for this product. No consent banner as a shipping gate. This is not a GDPR legal opinion.
- **Fits the actual edge.** Sites are CloudFront, not orange-cloud. Manual snippet is the only honest setup; do not pretend auto-inject will work.
- **Reversible.** Snippet is env-gated. Unset the token, rebuild, it is gone. Tokens are in HTML anyway.

## Alternatives considered

| Option | Rejected because |
| --- | --- |
| Wait for Umami (Phase 2) | Couples visitor analytics to VPS spend. Weeks/months of no page-view signal for no technical reason |
| Plausible hosted ($9/mo) | Paid SaaS for a problem the free beacon already covers |
| Google Analytics / GTM | Cookies, consent theatre, the opposite privacy default |
| One Cloudflare site for all four hostnames | Mixes surfaces; tokens and hostnames should match deploy units |
| Enable on TEST/STAGE/local | Fixture and rehearsal traffic pollute production series |

## Consequences

- **Positive:** Visitor + coarse RUM signal before any hosting invoice. Quiz SPA can use `spa: true` (History API). Four tokens, four dashboards, same shape as four CloudFront distributions.
- **Negative:** Visitor data leaves the AWS account and sits in Cloudflare's dashboard. **No API** — this will not become a Grafana panel. Dual-running with Umami later means two numbers that will disagree. CWV is Chromium-first.
- **Privacy honesty:** "No cookie banner" is not "no third party." Cloudflare sees beacons. CloudFront logs still have IPs. Say both.
- **Revisit trigger:** If Umami is live and trusted, decide keep / drop Cloudflare. If Cloudflare CWV is enough, skip or shrink Phase 3. If a CSP is added at CloudFront, allowlist `static.cloudflareinsights.com` and `cloudflareinsights.com` or the beacon dies silently.

## Implementation

How-to (tokens, file paths, CI, SPA, verification): [`../03 plans/02 - adding-cloudflare-web-analytics.md`](../03%20plans/02%20-%20adding-cloudflare-web-analytics.md).
