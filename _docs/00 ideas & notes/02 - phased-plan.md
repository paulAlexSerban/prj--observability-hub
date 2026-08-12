## Phased development plan - KEPT FOR INSPIRATION - NOT USED IN THE PROJECT

One structural note before the phases: your list has Loki (logs) and Prometheus-style metrics implied, but nothing for **traces**. If you're instrumenting with OpenTelemetry, you'll want **Grafana Tempo** in the stack too, or traces have nowhere to land. I've included it below — worth deciding now if you want to skip it and do metrics+logs only.

**Phase 0 — Foundations (infra as code)**
- Terraform: VPS resource, SSH keys, firewall rules, DNS records (delegate a subdomain like `*.argus.yourdomain.com` if your domains live in Route53)
- Decide state backend (S3 backend + DynamoDB lock table is cheap and fits your existing AWS footprint)
- Base OS hardening: unattended upgrades, fail2ban or equivalent, non-root deploy user

**Phase 1 — Reverse proxy + first visible win**
- Traefik with automatic Let's Encrypt certs, secured dashboard (basic auth at minimum)
- Uptime Kuma behind it — gives you a working status page across all projects almost immediately, low effort/high payoff
- This phase should feel "done" fast — it's your motivation checkpoint

**Phase 2 — Metrics core**
- Prometheus + node_exporter (VPS health)
- Grafana, wired to Prometheus, one dashboard per project as a placeholder
- YACE for the AWS-hosted project(s) — CloudWatch metrics into Prometheus for free

**Phase 3 — Logs**
- Loki + Grafana Alloy (or Promtail) shipping container logs and Traefik access logs
- Correlate logs with the metrics dashboards from Phase 2

**Phase 4 — Traces + real app instrumentation**
- Add Tempo if you want traces (see note above)
- Instrument the apps with backends (quiz app, news aggregator) using OpenTelemetry SDKs, exporting to Alloy/OTel Collector, fanning out to Prometheus/Loki/Tempo
- Static sites (portfolio, blog) skip this phase — they have nothing to instrument

**Phase 5 — Error tracking**
- GlitchTip, one project per app, DSNs wired into each codebase's error handler
- Alert routing from GlitchTip into the same channel as everything else

**Phase 6 — Product analytics**
- Umami, one site per project — portfolio, blog, quiz app, news feed
- Keep this separate from the observability side conceptually (it's about visitors, not health)

**Phase 7 — Alerting & unification**
- Grafana Alerting rules across metrics/logs/uptime, routed to Telegram or Discord
- One combined "fleet" dashboard: uptime + error rate + latency across all projects at a glance
- Runbook notes for yourself: what each alert means, what to check first

**Phase 8 — Hardening & repeatability**
- Auth in front of Grafana/Traefik dashboards (Authelia or oauth2-proxy) instead of basic auth
- Secrets via SOPS+age or similar, referenced from Terraform, not committed in plaintext
- A "new project" checklist/template (Terraform module + compose fragment) so adding the next app is copy-paste, not redesign

Each phase is independently useful — you could stop after Phase 3 and already have a solid personal observability setup. Phases 4–6 are where it becomes genuinely full-stack across all your projects, and 7–8 are what make it maintainable a year from now instead of something you have to relearn.