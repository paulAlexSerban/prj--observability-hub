# Local Phase 0 stack

Local-only Grafana + clickhouse-local queries over CloudFront metrics and access logs. Nothing is exposed beyond `127.0.0.1`.

## Prerequisites

1. CloudFront access logging enabled (done in `prj--personal-portfolio--v3` prod).
2. Read-only IAM key applied from `../aws` and copied into `.env`.

```bash
cp .env.example .env
# fill AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from:
#   cd ../aws && terraform output -raw access_key_id
#   cd ../aws && terraform output -raw secret_access_key
```

## Grafana (CloudWatch)

```bash
docker compose -f docker-compose.local.yml --env-file .env up -d
# open http://127.0.0.1:3000  (admin / admin by default)
```

Dashboard: **CloudFront overview** (folder Observability Hub) — requests, 4xx/5xx, bytes, total error rate per site.

Note: CloudFront **CacheHitRate** is not in the free metric set (it needs paid “additional metrics”). For a $0 cache hit ratio, use the clickhouse query below.

## clickhouse-local (access logs)

```bash
./scripts/query.sh top-paths
./scripts/query.sh top-paths blog.paulserban.eu
./scripts/query.sh status-breakdown
./scripts/query.sh cache-hit-ratio quiz.paulserban.eu
./scripts/query.sh referrers
```

CloudFront standard logs often take a while to appear after logging is first enabled — empty results shortly after apply are expected.
