# Local Phase 0 stack

Local-only Grafana + Loki (CloudFront access logs) + clickhouse-local (ad-hoc SQL). Nothing is exposed beyond `127.0.0.1`.

## Prerequisites

1. CloudFront access logging enabled (done in `prj--personal-portfolio--v3` prod).
2. Read-only IAM key applied from `../aws` and copied into `.env`.

```bash
cp .env.example .env
# fill AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from:
#   cd ../aws && terraform output -raw access_key_id
#   cd ../aws && terraform output -raw secret_access_key
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
| `grafana` | Dashboards (CloudWatch metrics + Loki logs) |
| `loki` | Log store for CloudFront access logs |
| `cf-log-sync` | `aws s3 sync` of the access-log bucket every 5 minutes |
| `alloy` | Decompress/parse `.gz` logs and push to Loki |

First sync + Alloy ingest usually finishes within a few minutes of `up`.

## Grafana dashboards

- **CloudFront overview** — CloudWatch metrics (requests, 4xx/5xx, bytes) plus **cache hit rate from Loki access logs** (free stand-in for paid CloudWatch `CacheHitRate`).
- **CloudFront access logs** — Loki aggregations (volume by site, status codes, cache `result_type`, top paths, internal/external referrers, edge POPs, client IPs, raw logs).
  - Edge POP codes (e.g. `IAD55-P9`) are metro/airport style, not country.
  - Unique IP count in Grafana is approximate (series count); use clickhouse `unique-ips` for exact.

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
```

CloudFront standard logs often take a while to appear after logging is first enabled — empty results shortly after apply are expected.
