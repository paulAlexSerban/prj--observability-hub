# Observability Stack

Self-hosted observability, analytics, and monitoring for my online projects - currently covering **paulserban.eu**, **blog.paulserban.eu**, **quiz.paulserban.eu**, and **news-feed.paulserban.eu** (Astro SSG / SPA, hosted on AWS S3 + CloudFront + Route53), designed to extend to any future project without re-architecting.

## Goals

- Traffic and CDN visibility (requests, error rates, cache performance) without relying on the AWS console
- Privacy-friendly page analytics - no cookie banners; Cloudflare Web Analytics as a $0 bridge (Phase 0b), Umami later if we want to own the rows
- Real User Monitoring for Core Web Vitals (LCP/CLS/INP) from actual visitors
- Uptime monitoring, checked from outside my own network
- Infra health (VPS resource usage) and, eventually, centralized logs and JS error tracking
- All of it cheap - no per-seat SaaS pricing. Self-hosted where it earns the VPS; Cloudflare Web Analytics is the explicit $0 exception (ADR-003).

## Architecture

| Concern                | Tool                                  | Deployment          |
| ---------------------- | ------------------------------------- | ------------------- |
| Reverse proxy / TLS    | Traefik                               | VPS, Docker Compose |
| Page analytics (now)   | Cloudflare Web Analytics (JS beacon)  | Cloudflare, prod-only |
| Page analytics (later) | Umami + Postgres                      | VPS                 |
| Uptime monitoring      | Uptime Kuma                           | VPS                 |
| Infra metrics          | Prometheus + node_exporter            | VPS                 |
| CloudFront/S3 metrics  | Grafana CloudWatch data source / YACE | Local → VPS         |
| Access-log SQL (CLI)   | clickhouse-local                      | Local (Docker one-shot) |
| Access-log dashboards  | Grafana Loki + Alloy                  | Local → VPS (Phase 6) |
| Dashboards             | Grafana                               | Local → VPS         |
| Logs (later)           | Grafana Loki + Alloy                  | VPS                 |
| Error tracking (later) | GlitchTip                             | VPS                 |

**Key decisions:**
- Docker Compose over Kubernetes - see [`ADR-001`](_docs/02 architecture-knowledge-management/adr--001--orchestration.md). Single-node, single-replica workloads don't justify an orchestrator's fixed resource/complexity tax.
- Traefik over Caddy for reverse proxy - Docker-provider label-based routing, no shared config file to edit per service added.
- clickhouse-local over Athena for Phase 0 ad-hoc SQL - see [`ADR-002`](_docs/02 architecture-knowledge-management/adr--002--query-engine.md). Grafana log UI uses Loki (Phase 6 practiced locally), not a ClickHouse server.
- Cloudflare Web Analytics now, Umami later - see [`ADR-003`](_docs/02 architecture-knowledge-management/adr--003--cloudflare-web-analytics.md). Visitor analytics must not wait on a VPS. How-to: [`02 - adding-cloudflare-web-analytics.md`](_docs/03%20plans/02%20-%20adding-cloudflare-web-analytics.md).

## Repository layout

```
infrastructure/
  aws/          # Phase 0 read-only IAM user (Terraform)
  local/        # docker-compose.local.yml, Grafana provisioning, clickhouse queries
_docs/          # spikes, phased plan, ADRs
```

CloudFront access logging (shared log bucket + `logging_config` on site/blog/quiz/news) lives in `prj--personal-portfolio--v3` Terraform, which owns the distributions.

## Implementation Plan

Built out in gated phases - each phase has a fixed objective, concrete deliverables, and an exit gate before moving to the next. Full detail in [`01 - phased-plan.md`](./_docs/03%20plans/01%20-%20phased-plan.md).

| Phase | Concern                                                           | Hosting           | Status      |
| ----- | ----------------------------------------------------------------- | ----------------- | ----------- |
| 0     | Local AWS log aggregation (CloudWatch + Loki access logs + clickhouse-local CLI) | Local machine, $0 | Done        |
| 0b    | Cloudflare Web Analytics (JS beacon, four prod hostnames)         | Cloudflare, $0    | Snippets in apps — add production env vars |
| 1     | VPS provisioning + Traefik platform foundation                    | VPS               | Not started |
| 2     | Owned page analytics (Umami)                                      | VPS               | Not started |
| 3     | Owned RUM / Core Web Vitals (optional if CF CWV is enough)        | VPS               | Not started |
| 4     | Uptime / synthetic monitoring (Uptime Kuma)                       | VPS               | Not started |
| 5     | Infra metrics + unified Grafana dashboards                        | VPS               | Not started |
| 6     | Log aggregation + error tracking (optional)                       | VPS               | Not started |

Phase 0 and 0b require no hosting spend. 0b how-to: [`02 - adding-cloudflare-web-analytics.md`](./_docs/03%20plans/02%20-%20adding-cloudflare-web-analytics.md). VPS spend starts at Phase 1.

## Getting Started (Phase 0)

1. Enable CloudFront access logging to the shared S3 bucket (already applied in `prj--personal-portfolio--v3` prod for site/blog/quiz/news-feed).
2. Apply the read-only IAM user and copy keys into local env:
   ```bash
   cd infrastructure/aws && terraform apply
   cd ../local && cp .env.example .env
   # paste: terraform -chdir=../aws output -raw access_key_id / secret_access_key
   ```
3. Start the local stack (Grafana + Loki + Alloy + S3 sync):
   ```bash
   make compose_up
   # http://127.0.0.1:3000  (admin / value of GRAFANA_ADMIN_PASSWORD)
   # Dashboards: CloudFront health (metrics + ops) + CloudFront traffic (Loki)
   ```
4. Optional — ad-hoc SQL with clickhouse-local (CLI, not Grafana):
   ```bash
   ./scripts/query.sh top-paths
   ./scripts/query.sh status-breakdown blog.paulserban.eu
   ./scripts/query.sh cache-hit-ratio
   ./scripts/query.sh referrers quiz.paulserban.eu
   ./scripts/query.sh unique-ips
   ./scripts/query.sh top-ips
   ./scripts/query.sh edge-pops blog.paulserban.eu
   ./scripts/query.sh top-paths news-feed.paulserban.eu
   ```

More detail: [`infrastructure/local/README.md`](infrastructure/local/README.md). Exit criteria for this phase are in the phased plan doc.

## Scope

Initial rollout targets the four sites above. The stack is intentionally domain-agnostic (Umami/Uptime Kuma/Grafana all support multiple sites per instance), so adding a new project later means adding a site entry and a monitor, not standing up new infrastructure.

## License

Personal infrastructure project - no license, not intended for external reuse as-is.
