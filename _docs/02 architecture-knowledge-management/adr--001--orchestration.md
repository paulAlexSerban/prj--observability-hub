# ADR-001: Use Docker Compose (not Kubernetes) for Self-Hosted Observability Stack

## Status
Accepted

## Date
2026-08-10

## Context

The site (Astro SSG, hosted on S3 + CloudFront + Route53) needs observability: web analytics, uptime monitoring, error tracking, infra metrics, and log aggregation. The target deployment is a single low-cost VPS (~€4.50–6/mo, e.g. Hetzner CX22, 2 vCPU / 4GB RAM), covering three domains (paulserban.eu, blog.paulserban.eu, quiz.paulserban.eu).

The proposed stack is entirely single-node, single-replica:

- Traefik (reverse proxy / TLS)
- Umami + Postgres (web analytics)
- Uptime Kuma (uptime monitoring)
- GlitchTip (error tracking)
- Prometheus + node_exporter + YACE (infra & CloudWatch metrics)
- Grafana Loki + Alloy (log aggregation)
- Grafana (dashboards)

Two deployment models were evaluated: Kubernetes (via k3s, the only viable lightweight option for a single small VPS) and Docker Compose.

## Decision

Deploy the stack with **Docker Compose** on a single VPS. Kubernetes (including k3s) is explicitly rejected for this use case.

## Rationale

- **No multi-node workload exists.** Kubernetes' core value — scheduling across nodes, failover across node loss, rolling multi-replica deployments — doesn't apply when there is exactly one node and every service runs as a single replica.
- **Fixed resource tax with no operational return.** Even k3s (the lightest viable option) consumes ~700MB RAM and ~0.3–0.5 vCPU idle just for the control plane, before any workload starts. Vanilla kubeadm k8s needs 2GB+ for etcd/API server/controller-manager/scheduler alone and isn't viable on a budget VPS at all.
- **Cost doubles for no functional gain.** The full stack fits in ~4GB under Docker Compose (CX22, ~€4.50/mo). The same stack under k3s needs ~7–8GB of headroom once the control plane tax is added, pushing the requirement to a CX32-class VPS (~€9/mo) — roughly 2x the cost for identical functionality.
- **Operational complexity isn't free.** k8s introduces manifests/Helm charts, a networking layer (CNI), ingress controllers, and its own upgrade/failure surface — all complexity to manage an orchestrator that is orchestrating nothing more than what Compose already handles with a single `docker-compose.yml`.
- **Docker Compose meets every actual requirement**: service definitions, restart policies, shared networks, volume persistence, and `docker compose up -d` deployment are sufficient for a single-node, single-replica stack.

## Alternatives Considered

| Option                       | Rejected because                                                                                                             |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Vanilla Kubernetes (kubeadm) | Control plane alone requires more RAM than the entire target VPS                                                             |
| k3s                          | Viable but imposes ~700MB–1GB fixed overhead and roughly doubles VPS cost for no operational benefit on a single node        |
| Managed k8s (EKS, etc.)      | Introduces recurring cloud costs disproportionate to a personal/portfolio-scale stack; defeats the "cheap, self-hosted" goal |

## Consequences

- **Positive:** Lower cost (~€4.50–6/mo vs ~€9/mo), simpler mental model, faster to stand up, easier to maintain solo, no orchestration layer to patch/upgrade.
- **Negative:** No built-in self-healing across node failure (irrelevant at single-node scale), no native horizontal scaling if traffic/data volume grows significantly beyond current needs.
- **Revisit trigger:** If the stack needs to scale beyond one node, requires high availability guarantees, or if k3s adoption becomes a deliberate goal in itself (e.g. for a build-in-public/portfolio blog post), this decision should be revisited — the rejection here is scoped to "no multi-node need" and "cost/simplicity priority," not a blanket rejection of k8s.