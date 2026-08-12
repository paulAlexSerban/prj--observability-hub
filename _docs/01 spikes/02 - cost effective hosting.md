Here's a self-hosted stack that covers everything on one cheap VPS, sized for your setup (S3/CloudFront/Route53 + Astro + 3 domains).

**VPS**
Hetzner CX22 (2 vCPU/4GB/~€4.5/mo) is the sweet spot — everything below fits comfortably, with headroom. CX11 (1vCPU/2GB) can work if you're careful with Loki/Prometheus retention, but 4GB avoids swap thrashing.

**Stack (all Docker Compose, one `docker-compose.yml`)**

| Layer                                 | Tool                                       | Why                                                                                 |
| ------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------- |
| Reverse proxy + TLS                   | **Caddy**                                  | auto Let's Encrypt, trivial config, low overhead vs Traefik                         |
| Web analytics                         | **Umami** (+ Postgres)                     | covers paulserban.eu, blog, quiz in one instance, one JS snippet per site           |
| Uptime monitoring                     | **Uptime Kuma**                            | free, self-hosted, no API limits like UptimeRobot's free tier                       |
| Error tracking                        | **GlitchTip**                              | self-hosted Sentry-compatible, much lighter than real Sentry                        |
| Infra metrics                         | **Prometheus** + **node_exporter**         | VPS health (CPU/mem/disk)                                                           |
| CloudFront/S3 metrics into Prometheus | **yet-another-cloudwatch-exporter (YACE)** | pulls CloudWatch metrics, exposes `/metrics` for Prometheus to scrape               |
| Logs                                  | **Grafana Loki** + **Alloy** (or Promtail) | ship CloudFront access logs (from S3) + VPS logs                                    |
| Dashboards                            | **Grafana**                                | single pane over Prometheus + Loki + (optionally) Umami's Postgres as a data source |

**Data flow**
- Astro sites → Umami JS snippet → Umami/Postgres (visitor analytics)
- CloudFront → access logs to S3 → small cron/script pulls new logs → Loki (via Alloy) for querying in Grafana
- CloudWatch (CloudFront/S3 built-in metrics) → YACE → Prometheus → Grafana
- VPS itself → node_exporter → Prometheus → Grafana
- Uptime Kuma pings all three domains independently, alerts via Telegram/Discord/email webhook (free)
- GlitchTip DSN in your Astro islands' JS for client-side error capture

**Cost**
- VPS: €4.50–6/mo (Hetzner CX22)
- Route53 health checks: skip, Uptime Kuma replaces this
- CloudWatch API calls (YACE polling): pennies, stays in free tier at low poll frequency (e.g., every 5 min)
- Total: **~€5/mo**, everything else free/open-source

**Sequencing if you build it out**
1. Caddy + Umami first (immediate value, low complexity)
2. Uptime Kuma (5 min setup, alerts you if the site goes down)
3. Prometheus + node_exporter + Grafana (VPS + basic dashboards)
4. YACE for CloudFront/S3 metrics into the same Grafana
5. Loki + Alloy for CloudFront access logs (highest effort/lowest urgency — do this last)
6. GlitchTip only if your Astro islands have enough client-side JS to warrant error tracking

Want the `docker-compose.yml` for this, or the Caddy config for routing all these services under subdomains (e.g., `analytics.paulserban.eu`, `status.paulserban.eu`, `grafana.paulserban.eu`)?