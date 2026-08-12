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

## Phase 1 — VPS Decision & Platform Foundation

**Objective:** Pick hosting for the pieces that *must* be public and always-on (visitor analytics beacon, uptime checks pinging from outside your network, RUM ingestion), then stand up the base platform there.

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

---

## Phase 2 — Privacy-Friendly Page Analytics (client-side)

**Objective:** Page views, referrers, and visitor counts without cookie banners, across all three domains.

**Deliverables:**
- Umami + Postgres added to `docker-compose.yml`, Traefik labels routing `analytics.paulserban.eu`
- One Umami site entry per domain (paulserban.eu, blog, quiz)
- Tracking snippet added to Astro's shared layout (single include point, not per-page)
- Verify events land for at least one real page view per domain

**Exit gate:** Dashboard shows live traffic for all three domains with no cookie consent banner required.

---

## Phase 3 — Real User Monitoring / Core Web Vitals

**Objective:** Know actual LCP/CLS/INP experienced by real visitors, not just lab/synthetic scores.

**Deliverables:**
- `web-vitals` npm package in the Astro layout, sends a `navigator.sendBeacon` on each metric
- Simplest ingestion path: post into Umami as a custom event (no new service); alternative is a small endpoint writing into Postgres/Loki for raw distributions
- Grafana panel (or Umami custom-event view) showing P75 LCP/CLS/INP trend per domain

**Exit gate:** A 7-day Core Web Vitals trend line is visible for at least one domain, sourced from real visits.

**Note:** Datadog RUM was in the original notes as an option — skipped to stay inside the self-hosted/cheap constraint. Revisit only if you specifically want Datadog-unified dashboards for portfolio reasons.

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
| 0     | CDN/traffic validation   | Local machine, $0  | Grafana (local), Athena                  | Athena + local dashboard answer real questions |
| 1     | VPS + platform           | VPS (chosen above) | Traefik                                  | TLS works, repo reproducible                   |
| 2     | Page analytics           | VPS                | Umami + Postgres                         | Live traffic on all 3 domains                  |
| 3     | RUM                      | VPS                | web-vitals beacon                        | 7-day CWV trend visible                        |
| 4     | Uptime                   | VPS                | Uptime Kuma                              | Alert fires on test outage                     |
| 5     | Infra + unified view     | VPS                | Prometheus, node_exporter, YACE, Grafana | One dashboard for VPS + CDN + CWV              |
| 6     | Logs + errors (optional) | VPS                | Loki, Alloy, GlitchTip                   | Log search + JS error capture work             |

Phase 0 costs nothing and de-risks the rest. Real hosting spend only starts at Phase 1, once the CDN-analytics approach is already proven to work.