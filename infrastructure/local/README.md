# Local Phase 0 stack

Local-only Grafana + Loki (CloudFront access logs) + clickhouse-local (ad-hoc SQL). Nothing is exposed beyond `127.0.0.1`.

## Prerequisites

1. CloudFront access logging enabled for all six distributions: site/blog/quiz/news-feed/news-data/assets (done in `prj--personal-portfolio--v3` prod).
2. Read-only IAM key applied from `../aws` and copied into `.env`.
3. (Optional, for the Cloudflare Web Analytics dashboard) a Cloudflare API token with **Account Analytics: Read**, plus the Cloudflare **Account ID** in `grafana/dashboards/cloudflare-web-analytics.json` query variables (`accountTag`). Panels filter by hostname (`requestHost`), not the JS beacon token.

```bash
cp .env.example .env
# fill AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from:
#   cd ../aws && terraform output -raw access_key_id
#   cd ../aws && terraform output -raw secret_access_key
#
# optional — Cloudflare RUM in Grafana:
#   CF_API_TOKEN  from dash.cloudflare.com → Account API Tokens
#                 (template "Read analytics and logs", or Account Analytics: Read)
#   accountTag in grafana/dashboards/cloudflare-web-analytics.json
#                 — Account Home / any dash.cloudflare.com/<id>/ URL
#   Do not use the JS snippet `token` as a GraphQL siteTag; queries filter by hostname.
```

## Start the stack

```bash
# from repo root (same pattern as prj--personal-portfolio--v3)
make compose_up
# or from this directory:
docker compose -f docker-compose.local.yml --env-file .env up -d
# open http://127.0.0.1:3000  (admin / admin by default)
```

Services:

| Service | Role |
| --- | --- |
| `grafana` | Dashboards (CloudWatch metrics + Loki logs + Cloudflare GraphQL via Infinity) |
| `loki` | Log store for CloudFront access logs |
| `cf-log-sync` | `aws s3 sync` of the access-log bucket every 5 minutes |
| `alloy` | Decompress/parse `.gz` logs and push to Loki |

First sync + Alloy ingest usually finishes within a few minutes of `up`.

## Grafana dashboards

- **CloudFront health** (`cloudfront-overview`) — CDN glance view: CloudWatch KPIs (requests, 4xx/5xx, bytes), Loki cache hit %, result types, top error paths, top cache-miss paths. Site variable filters Loki panels; CloudWatch shows all six distributions (paulserban.eu, blog, quiz, news-feed, news-data, assets).
- **CloudFront traffic** (`cloudfront-access-logs`) — Content vs asset paths, bytes by path, referrer **hosts** (internal/external), direct vs referred, collapsed forensics (IPs, 404s, raw logs).
  - Exact unique IPs / edge POPs: ClickHouse CLI only (`./scripts/query.sh unique-ips`, `top-ips`, `edge-pops`) — not Grafana.
- **AWS Billing** (`aws-billing`) — month-to-date **estimated** charges from CloudWatch `AWS/Billing` (`EstimatedCharges` in `us-east-1`): account total plus a dynamic per-service breakdown. This is AWS's periodic (~6h) estimate, not the invoice (no tax, credits, or per-resource/tag split).
  - **One-time AWS step:** enable **Receive CloudWatch Billing Alerts** in [Billing preferences](https://console.aws.amazon.com/costmanagement/). Metrics appear in `us-east-1` after ~15 minutes. Empty panels until that is on. No extra IAM or datasource — the existing CloudWatch key already covers metric reads.
- **Cloudflare Web Analytics** (`cloudflare-web-analytics`) — visitor RUM from Cloudflare's GraphQL API (`rumPageloadEventsAdaptiveGroups` + `rumWebVitalsEventsAdaptiveGroups`): visits, page views, top paths/referrers/browsers/OS/countries, LCP/INP/CLS p75, plus a correlation row against CloudWatch CloudFront Requests. Four beacon hostnames only (portfolio, blog, news-feed, quiz — not assets/news-data).
  - **Setup:** `CF_API_TOKEN` in `.env`; `accountTag` in the dashboard JSON (see Prerequisites). Recreate Grafana after adding the token so Infinity **3.7.1** installs (`GF_INSTALL_PLUGINS`; 4.x needs Grafana ≥11.6.11). Empty panels until both are done. Queries filter by `requestHost` — the JS beacon token is not a GraphQL site id.
  - **Not comparable to access logs.** Cloudflare counts browsers that ran JS; CloudFront counts every edge object. They should disagree.

## clickhouse-local (ad-hoc SQL, CLI only)

Grafana does **not** use ClickHouse — that stays a one-shot CLI for SQL exploration (ADR-002). Loki is the Grafana log path (Phase 6 practice).

```bash
./scripts/query.sh top-paths
./scripts/query.sh top-paths blog.paulserban.eu
./scripts/query.sh status-breakdown
./scripts/query.sh cache-hit-ratio quiz.paulserban.eu
./scripts/query.sh referrers
./scripts/query.sh unique-ips
./scripts/query.sh top-ips
./scripts/query.sh edge-pops
./scripts/query.sh top-paths news-feed.paulserban.eu
./scripts/query.sh top-paths news-data.paulserban.eu
./scripts/query.sh cache-hit-ratio assets.paulserban.eu
```

CloudFront standard logs often take a while to appear after logging is first enabled — empty results shortly after apply are expected.
