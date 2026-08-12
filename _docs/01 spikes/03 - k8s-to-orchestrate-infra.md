Short answer: **k8s adds overhead without adding value here** — but if you want it for practice/portfolio reasons, here's the real sizing.

**Why it's overkill for this stack**
- Everything in the plan is a single-node, single-replica deployment. K8s's core value (scheduling across nodes, self-healing across failures, rolling multi-replica deploys) doesn't apply to one VPS.
- You'd be running an orchestrator to orchestrate... one node. All the complexity buys you nothing operationally that Docker Compose doesn't already give you here.

**Resource cost of adding k8s itself**
- **k3s** (lightweight k8s, the only sane choice for a single small VPS) — control plane alone: ~500MB–1GB RAM, ~0.3–0.5 vCPU idle.
- Full **kubeadm/vanilla k8s** — control plane alone needs 2GB+ RAM just for etcd/API server/controller-manager/scheduler, before any workload runs. Not viable on a cheap VPS.
- So k3s is the only realistic option, and even then you're paying a fixed tax before any app runs.

**Sizing with k3s + this stack**
| Component | RAM |
|---|---|
| k3s control plane | ~700MB |
| Umami + Postgres | ~350MB |
| Uptime Kuma | ~100MB |
| GlitchTip (+ Postgres/Redis) | ~500MB |
| Prometheus | ~300–500MB (depends on retention) |
| Grafana | ~150MB |
| Loki + Alloy | ~300–400MB |
| YACE, node_exporter | ~50MB |
| **Total** | **~2.5–3GB** |

That means minimum **CX32 (4vCPU/8GB, ~€9/mo)** to run comfortably with headroom, vs **CX22 (4GB, ~€4.5/mo)** for the plain Docker Compose version. You're roughly doubling cost for the k8s tax alone, same workloads.

**Bottom line**
- Pure cost/simplicity goal → Docker Compose, skip k8s entirely.
- Portfolio/practice goal (e.g., "I want k3s on my CV/blog as a build-in-public post) → k3s is genuinely light enough to justify at €9/mo, and it's a believable single-node homelab setup worth writing up on blog.paulserban.eu.

Given you've already got AWS/DevOps depth from FanDuel, k3s here reads more as a learning/content angle than infra necessity — is that the direction you're leaning, or do you want the simplest path to just get monitoring live?