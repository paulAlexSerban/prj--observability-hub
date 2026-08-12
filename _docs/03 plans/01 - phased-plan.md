# Observability Stack — Phased Implementation Plan (v2)

**Target:** Astro SSG on S3 + CloudFront + Route53, across paulserban.eu, blog.paulserban.eu, quiz.paulserban.eu
**Deployment model:** Docker Compose (see ADR-001), reverse proxy via Traefik
**Structure:** Each phase has a fixed objective, concrete deliverables, and an exit gate — don't start the next phase until the current gate is met. Phase 0 requires no hosting spend at all; hosting is only introduced once local validation proves the approach.

---

## Phase 0 — Local AWS Log Aggregation (no VPS, $0 hosting cost)

```notes
**CloudFront/S3-native telemetry (no extra JS)**
- **CloudFront access logs → S3** — free to enable, pay only for S3 storage (pennies). Query with **Athena** (pay-per-query, ~$5/TB scanned) for real traffic analytics without any client-side script.
- WON'T DO:**CloudFront real-time logs → Kinesis** if you want near-live dashboards, but this gets pricier — skip unless you need it.
- **CloudWatch metrics** for CloudFront (requests, error rate, bytes) are free at the basic level, just not very granular.
```

**Objective:** Prove out CDN/traffic visibility using data AWS already has, entirely on your own machine, before renting anything.

**Deliverables:**
- CloudFront access logging enabled → dedicated S3 bucket (lifecycle rule to expire/transition old logs)
- Local-only `docker-compose.yml` (runs on your dev machine, not exposed publicly) with Grafana connected via its **built-in CloudWatch data source** — no exporter needed for this step, just a read-only IAM key. This gives CloudFront requests/4xx/5xx/bytes dashboards immediately.
- Athena table + saved queries over the access log bucket (top paths, status code breakdown, cache hit ratio, referrers) — serverless, pay-per-query, pennies at this data volume
  - **Superseded for implementation by [`ADR-002`](../02%20architecture-knowledge-management/adr--002--query-engine.md):** Phase 0 uses **clickhouse-local** against the same S3 log bucket instead of Athena.
- Optional: a local Loki instance + a one-off script pulling recent S3 access logs, if you want to practice log-query patterns before committing to always-on log shipping

**Exit gate:** Local Grafana answers "is CloudFront serving cleanly this week" and a saved Athena query answers "top 10 paths and error rate, last 7 days" — both reproducible from a clean laptop, zero infrastructure rented.

**Why this comes first:** everything in this phase is either free (CloudWatch metrics, local Docker) or pennies (Athena, S3 storage). It validates the CDN-analytics half of the stack and de-risks the rest before any VPS spend is committed.

### Botes & Outcome
1. CloudFront access logging (prj--personal-portfolio--v3)
   - Shared bucket cf-access-logs.paulserban.eu (60-day lifecycle, log-delivery-write ACL)
   - Optional logging_config on the static-site module
   - Wired for site / blog / quiz in prod — applied successfully
2. Read-only IAM (prj--observability-hub/infrastructure/aws)
   - User observability-hub-readonly with CloudWatch + CloudFront list + S3 log-bucket read
   - Access key written to gitignored infrastructure/local/.env
3. Local Grafana (infrastructure/local)
   - docker compose -f docker-compose.local.yml up -d → healthy on http://127.0.0.1:3000
   - CloudWatch datasource provisioned; CloudFront overview dashboard loaded
   - Live metric query against E23PAQJ8T46O9C succeeded
4. clickhouse-local
   - Queries: top-paths, status-breakdown, cache-hit-ratio, referrers
   - Wrapper: ./scripts/query.sh <name> [prefix]
   - Verified against live logs (e.g. top paths + ~84% 200s already present)
5. Local Loki + Alloy (Phase 6 practiced early — Grafana access-log dashboards)
   - `cf-log-sync` pulls S3 access logs every 5 minutes
   - Alloy decompresses/parses CloudFront TSV → Loki (`job=cloudfront`, `site`, `status`, `result_type`)
   - Dashboard **CloudFront access logs**: volume, status, cache result type, top paths, referrers, raw logs
   - clickhouse-local stays CLI-only; no ClickHouse Grafana plugin
6. Docs
   - README Phase 0 → Done, Getting Started updated for Loki + clickhouse-local
   - ADR-002 records Athena → clickhouse-local; Grafana log UI = Loki

> Quick use
> ```bash
> # Grafana
>   - cd prj--observability-hub/infrastructure/local
>   - docker compose -f docker-compose.local.yml --env-file .env up -d
>   - http://127.0.0.1:3000  (admin / admin)
>   - Dashboards: CloudFront overview + CloudFront access logs
>   - Access-log SQL (optional CLI)
>   - ./scripts/query.sh top-paths
>   - ./scripts/query.sh status-breakdown blog.paulserban.eu
>   - Default Grafana password is in .env (GRAFANA_ADMIN_PASSWORD)
> ```

---

## Phase 0b — Cloudflare Web Analytics (no VPS, $0 hosting)

**Does not wait on Phase 1.** Visitor analytics is a JS beacon, not a container. Shipping it after Lightsail would couple a product question to a hosting invoice.

See [`ADR-003`](../02%20architecture-knowledge-management/adr--003--cloudflare-web-analytics.md) and the how-to: [`02 - adding-cloudflare-web-analytics.md`](./02%20-%20adding-cloudflare-web-analytics.md).

**Objective:** Page views, referrers, and coarse Core Web Vitals from real browsers, across all four production hostnames, with no cookie banner and no VPS.

**Deliverables:**
- One Cloudflare Web Analytics site (token) per production hostname — `paulserban.eu`, `blog.`, `quiz.`, `news-feed.`
- Manual JS snippet (sites are CloudFront, **not** orange-cloud — auto-inject will not run)
- Astro: env-gated snippet in each `BaseTemplate.astro` (`PUBLIC_CF_BEACON_TOKEN`)
- Quiz PWA: inject from `main.tsx` with `"spa": true` (`VITE_CF_BEACON_TOKEN`)
- Tokens only on **production** CI; local / DEV / TEST / STAGE unset
- Verify a real page view per hostname in the Cloudflare dashboard

**Exit gate:** Cloudflare dashboard shows at least one real visit per production hostname; non-prod hosts show none.

**Why this is not Phase 2:** Umami still owns the "we hold the event rows" story. Cloudflare is the bridge so that question is not unanswered until a box exists. Data leaves the AWS account; there is no API into Grafana. Named, not accidental.

**Overlap with Phase 3:** the beacon already reports LCP / INP / CLS (Chromium-first). Do not add a second `web-vitals` pipeline until Cloudflare's view is insufficient.

---

## Phase 1 — VPS Decision & Platform Foundation

**Objective:** Pick hosting for the pieces that *must* be public and always-on (uptime checks from outside your network, later Umami / Grafana). Visitor analytics no longer waits on this box — that is Phase 0b. Then stand up the base platform.

**VPS options considered** (Hetzner's Cost-Optimized/CX tier is currently stock-constrained — availability depends on Hetzner having reduced-cost hardware on hand, so Regular Performance is what's actually orderable most of the time right now):

| Option                        | Specs             | Price                   | Trade-off                                                                                          |
| ----------------------------- | ----------------- | ----------------------- | -------------------------------------------------------------------------------------------------- |
| Hetzner CPX22 (Regular Perf.) | 2 vCPU / 4GB      | €7.99/mo                | Reliable, well-documented; CX tier may return to stock later                                       |
| Contabo Cloud VPS             | 4 vCPU / 8GB      | ~€4.50–4.95/mo (annual) | Best specs/€; unmanaged, variable-performance reputation                                           |
| AWS Lightsail                 | 1–2GB tier        | ~$5–10/mo               | Same AWS account/IAM as your existing S3+CloudFront+Route53                                        |
| Oracle Cloud Always Free      | 2 OCPU / 12GB ARM | $0                      | Free but capacity-constrained at signup; limits were just halved (Jun 2026); ARM64 images required |

**Recommendation:** AWS Lightsail, since the site's infra is already 100% AWS — no cross-account IAM setup needed when this VPS later pulls CloudWatch/S3 data itself, and billing stays in one place. Contabo is the pick if raw cost-per-GB is the only priority. Treat this as a default, not a mandate — swap freely.

**Deliverables:**
- VPS provisioned at the chosen provider, sized for ~2–3GB RAM minimum once the full stack (Umami+Postgres, Uptime Kuma, Prometheus, Grafana, later Loki) is running — the smallest tier at most providers is too tight
- Docker + Docker Compose installed, non-root deploy user, SSH key-only access, firewall (22, 80, 443 only)
- Traefik running via the Docker provider (label-based routing) with an ACME resolver for automatic TLS — no central config file to edit per phase, just labels on each new service
- DNS: subdomains pointed at the VPS (e.g. `analytics.`, `status.`, `grafana.`, `errors.` under paulserban.eu)
- `docker-compose.yml` skeleton in a private git repo (secrets via `.env`, not committed)

**Exit gate:** `https://status.paulserban.eu` (or a placeholder service) resolves with valid TLS through Traefik. Repo has a working `docker compose up -d` a second machine could reproduce from a fresh clone.

### Notes

Yes. Lightsail is a first-class resource in the Terraform AWS provider, so Phase 1 can stay in the same account/tooling as S3 + CloudFront + Route53.

What Terraform should own:

| Resource                                                       | Terraform type                                                   |
| -------------------------------------------------------------- | ---------------------------------------------------------------- |
| Instance (Ubuntu, size, AZ, SSH key, `user_data`)              | `aws_lightsail_instance`                                         |
| Stable public IP (required — default IP changes on stop/start) | `aws_lightsail_static_ip` + `aws_lightsail_static_ip_attachment` |
| Firewall: 22 / 80 / 443 only                                   | `aws_lightsail_instance_public_ports`                            |
| DNS: `analytics.`, `status.`, `grafana.`, `errors.` → that IP  | `aws_route53_record` (zone already in the portfolio stack)       |

`user_data` can install Docker, Compose, a non-root deploy user, and SSH-key-only login. Traefik + `docker-compose.yml` stay in git and get deployed onto the box; do not try to manage containers as Terraform resources.

Caveats that matter for *your* plan:

1. **RAM.** The plan says ~2–3GB once Umami, Postgres, Grafana, and later Loki are on it. The $5 Lightsail bundle is 1GB and will not hold. Budget the **$12/mo 2GB** or **$24/mo 4GB** bundle, not the $5–10 line in the table.
2. **IAM from the VPS.** Lightsail is weaker than EC2 for instance profiles. For CloudWatch/S3 reads, reuse the same pattern as Phase 0 (IAM user + keys on the instance) unless you explicitly add Lightsail instance-role support. Same AWS account still avoids cross-account IAM.
3. **Region.** Lightsail is regional. Put the instance in `eu-central-1` next to the log bucket; CloudFront metrics stay `us-east-1` / `Region=Global` as they are now.
4. **DNS ownership.** A records can live in hub Terraform if you pass `hosted_zone_id`, or stay in `prj--personal-portfolio--v3` prod. Pick one so you do not fight over the zone.

So: Terraform for instance + static IP + ports + DNS; Compose for Traefik and everything that comes in Phases 2–6. That matches the Phase 1 exit gate (`https://status.paulserban.eu` with TLS) without standing up EC2/VPC.

---

## Phase 2 — Privacy-Friendly Page Analytics (self-hosted Umami)

**Objective:** Own page-view data (not only Cloudflare's dashboard) across all four domains, still without a cookie banner.

**Deliverables:**
- Umami + Postgres added to `docker-compose.yml`, Traefik labels routing `analytics.paulserban.eu`
- One Umami site entry per domain (paulserban.eu, blog, quiz, news-feed)
- Tracking snippet added next to the Cloudflare beacon (same layout include points) — env-gated, prod-only
- Verify events land for at least one real page view per domain
- After ~7 days of overlap, decide keep / drop Cloudflare Web Analytics (ADR-003 revisit)

**Exit gate:** Umami dashboard shows live traffic for all four domains with no cookie consent banner required.

**Note:** Numbers will disagree with Cloudflare and with access logs. That is expected (JS vs JS-vendor vs CDN). Matching 1:1 means the pipeline is wrong.

---

## Phase 3 — Real User Monitoring / Core Web Vitals

**Objective:** Know actual LCP/CLS/INP experienced by real visitors, not just lab/synthetic scores — **in a system we own**, if Cloudflare's CWV view is not enough.

**Default:** **skip or shrink.** Phase 0b already lands CWV in the Cloudflare dashboard. Do not dual-instrument.

**If revisited (Umami live, or Cloudflare dropped / insufficient):**
- `web-vitals` npm package in the Astro layout, sends a `navigator.sendBeacon` on each metric
- Simplest ingestion path: post into Umami as a custom event (no new service); alternative is a small endpoint writing into Postgres/Loki for raw distributions
- Grafana panel (or Umami custom-event view) showing P75 LCP/CLS/INP trend per domain

**Exit gate (only if this phase runs):** A 7-day Core Web Vitals trend line is visible for at least one domain, sourced from real visits, **outside** the Cloudflare UI.

**Note:** Datadog RUM stays skipped. Cloudflare Web Analytics is the cheap RUM we actually turned on; Datadog would be the k8s mistake again.

---

## Phase 4 — Uptime / Synthetic Monitoring

**Objective:** Know within minutes if any domain goes down, checked from outside your own network.

**Deliverables:**
- Uptime Kuma added to `docker-compose.yml`, Traefik labels routing `status.paulserban.eu`
- Monitors for all three domains (HTTP check + optional keyword check on homepage content)
- Alert channel wired up (Telegram/Discord/email webhook)

**Exit gate:** A deliberate test outage produces an alert within the configured interval.

---

## Phase 5 — Infra Metrics, Logs & Unified Dashboards (VPS)

**Objective:** Migrate the Phase 0 local CloudWatch dashboards onto the always-on VPS, add VPS health, and unify everything in one Grafana.

**Deliverables:**
- Prometheus + node_exporter in the Compose stack (VPS CPU/mem/disk)
- YACE (yet-another-cloudwatch-exporter) for CloudFront + S3 metrics → Prometheus — or reuse Grafana's native CloudWatch data source from Phase 0 directly, whichever proved simpler locally
- Grafana on the VPS, routed via Traefik, data sources: Prometheus + Umami's Postgres
- Traefik's own Prometheus metrics endpoint enabled, for proxy-level request/latency data in the same Grafana
- Dashboards: VPS health, CloudFront traffic/error summary (carried over from Phase 0), Core Web Vitals trend

**Exit gate:** A single Grafana URL answers "is the VPS healthy, is CloudFront serving cleanly, are Core Web Vitals in range" without opening the AWS console or SSH-ing in.

---

## Phase 6 — Log Aggregation & Error Tracking (optional, highest effort)

**Objective:** Centralize logs and capture client-side JS errors, for deeper debugging when something actually breaks.

**Deliverables:**
- Grafana Loki + Alloy (or Promtail) added to the Compose stack
- CloudFront access logs shipped from S3 into Loki (small poller/cron, or Alloy's S3 source)
- Traefik access logs (JSON) also shipped into Loki
- GlitchTip added if Astro islands carry enough client-side JS to warrant error capture
- Loki added as a Grafana data source; log panel added to the Phase 5 dashboard

**Exit gate:** Can search CloudFront access logs by status code/path in Grafana Explore, and (if GlitchTip deployed) a deliberately thrown JS error shows up within a minute.

**Note:** Most likely phase to skip — Phases 0–5 already cover traffic, RUM, uptime, and infra health. Build this out only if log-level debugging becomes an actual pain point.

---

## Summary Table

| Phase | Concern                  | Hosting            | New services                             | Gate                                           |
| ----- | ------------------------ | ------------------ | ---------------------------------------- | ---------------------------------------------- |
| 0     | CDN/traffic validation   | Local machine, $0  | Grafana (local), clickhouse-local, Loki  | Dashboard + SQL answer real CDN questions      |
| 0b    | Visitor analytics + CWV  | Cloudflare SaaS, $0 | JS beacon in four apps                  | One real prod page view per hostname           |
| 1     | VPS + platform           | VPS (chosen above) | Traefik                                  | TLS works, repo reproducible                   |
| 2     | Owned page analytics     | VPS                | Umami + Postgres                         | Live traffic on all 4 domains; decide CF keep/drop |
| 3     | Owned RUM (optional)     | VPS                | web-vitals beacon                        | Only if CF CWV is insufficient                 |
| 4     | Uptime                   | VPS                | Uptime Kuma                              | Alert fires on test outage                     |
| 5     | Infra + unified view     | VPS                | Prometheus, node_exporter, YACE, Grafana | One dashboard for VPS + CDN + CWV              |
| 6     | Logs + errors (optional) | VPS                | Loki, Alloy, GlitchTip                   | Log search + JS error capture work             |

Phase 0 and 0b cost nothing in hosting and can run in parallel. Real VPS spend only starts at Phase 1.