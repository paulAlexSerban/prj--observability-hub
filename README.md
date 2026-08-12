# Observability Stack

Self-hosted observability, analytics, and monitoring for my online projects - currently covering **paulserban.eu**, **blog.paulserban.eu**, and **quiz.paulserban.eu** (all Astro SSG, hosted on AWS S3 + CloudFront + Route53), designed to extend to any future project without re-architecting.

## Goals

- Traffic and CDN visibility (requests, error rates, cache performance) without relying on the AWS console
- Privacy-friendly page analytics - no cookie banners, no third-party data sharing
- Real User Monitoring for Core Web Vitals (LCP/CLS/INP) from actual visitors
- Uptime monitoring, checked from outside my own network
- Infra health (VPS resource usage) and, eventually, centralized logs and JS error tracking
- All of it cheap and self-hosted - no per-seat SaaS pricing, no vendor lock-in

## Architecture

| Concern                | Tool                                  | Deployment          |
| ---------------------- | ------------------------------------- | ------------------- |
| Reverse proxy / TLS    | Traefik                               | VPS, Docker Compose |
| Page analytics         | Umami + Postgres                      | VPS                 |
| Uptime monitoring      | Uptime Kuma                           | VPS                 |
| Infra metrics          | Prometheus + node_exporter            | VPS                 |
| CloudFront/S3 metrics  | Grafana CloudWatch data source / YACE | Local → VPS         |
| Access-log SQL (Phase 0) | clickhouse-local                    | Local (Docker)      |
| Dashboards             | Grafana                               | Local → VPS         |
| Logs (later)           | Grafana Loki + Alloy                  | VPS                 |
| Error tracking (later) | GlitchTip                             | VPS                 |

**Key decisions:**
- Docker Compose over Kubernetes - see [`ADR-001`](_docs/02 architecture-knowledge-management/adr--001--orchestration.md). Single-node, single-replica workloads don't justify an orchestrator's fixed resource/complexity tax.
- Traefik over Caddy for reverse proxy - Docker-provider label-based routing, no shared config file to edit per service added.
- clickhouse-local over Athena for Phase 0 log SQL - see [`ADR-002`](_docs/02 architecture-knowledge-management/adr--002--query-engine.md).

## Repository layout

```
infrastructure/
  aws/          # Phase 0 read-only IAM user (Terraform)
  local/        # docker-compose.local.yml, Grafana provisioning, clickhouse queries
_docs/          # spikes, phased plan, ADRs
```

CloudFront access logging (shared log bucket + `logging_config` on site/blog/quiz) lives in `prj--personal-portfolio--v3` Terraform, which owns the distributions.

## Implementation Plan

Built out in gated phases - each phase has a fixed objective, concrete deliverables, and an exit gate before moving to the next. Full detail in [`01 - phased-plan.md`](./_docs/00 ideas & notes/01 - phased-plan.md).

| Phase | Concern                                                           | Hosting           | Status      |
| ----- | ----------------------------------------------------------------- | ----------------- | ----------- |
| 0     | Local AWS log aggregation (CloudFront/S3 via CloudWatch + clickhouse-local) | Local machine, $0 | Done        |
| 1     | VPS provisioning + Traefik platform foundation                    | VPS               | Not started |
| 2     | Privacy-friendly page analytics (Umami)                           | VPS               | Not started |
| 3     | Real User Monitoring / Core Web Vitals                            | VPS               | Not started |
| 4     | Uptime / synthetic monitoring (Uptime Kuma)                       | VPS               | Not started |
| 5     | Infra metrics + unified Grafana dashboards                        | VPS               | Not started |
| 6     | Log aggregation + error tracking (optional)                       | VPS               | Not started |

Phase 0 requires no hosting spend - it validates the CDN-analytics approach entirely on a local machine before any VPS is provisioned.

## Getting Started (Phase 0)

1. Enable CloudFront access logging to the shared S3 bucket (already applied in `prj--personal-portfolio--v3` prod for site/blog/quiz).
2. Apply the read-only IAM user and copy keys into local env:
   ```bash
   cd infrastructure/aws && terraform apply
   cd ../local && cp .env.example .env
   # paste: terraform -chdir=../aws output -raw access_key_id / secret_access_key
   ```
3. Start local Grafana (CloudWatch datasource + CloudFront overview dashboard):
   ```bash
   cd infrastructure/local
   docker compose -f docker-compose.local.yml --env-file .env up -d
   # http://127.0.0.1:3000  (admin / value of GRAFANA_ADMIN_PASSWORD)
   ```
4. Query access logs with clickhouse-local:
   ```bash
   ./scripts/query.sh top-paths
   ./scripts/query.sh status-breakdown blog.paulserban.eu
   ./scripts/query.sh cache-hit-ratio
   ./scripts/query.sh referrers quiz.paulserban.eu
   ```

More detail: [`infrastructure/local/README.md`](infrastructure/local/README.md). Exit criteria for this phase are in the phased plan doc.

## Scope

Initial rollout targets the three Astro sites above. The stack is intentionally domain-agnostic (Umami/Uptime Kuma/Grafana all support multiple sites per instance), so adding a new project later means adding a site entry and a monitor, not standing up new infrastructure.

## License

Personal infrastructure project - no license, not intended for external reuse as-is.
