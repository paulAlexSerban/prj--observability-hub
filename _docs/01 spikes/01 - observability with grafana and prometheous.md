Grafana + Prometheus is a heavier lift here, and it's not really a natural fit for a static site — worth being clear on why before deciding.

**Why it's awkward for this use case**
- Prometheus is a *pull-based metrics* system — it scrapes `/metrics` endpoints from running services. A static S3/CloudFront site has no server process to scrape. There's nothing for Prometheus to pull from natively.
- To get anything into Prometheus you'd need to bolt on exporters or a push gateway:
  - **CloudWatch Exporter** (or `yet-another-cloudwatch-exporter`) to pull CloudFront/S3 metrics from CloudWatch into Prometheus format — adds a service you have to run and maintain.
  - **Pushgateway** if you want client-side/RUM-style events (page views, web-vitals) shoved into Prometheus — this is the wrong tool for that job; Prometheus wasn't designed for high-cardinality per-user event data like page views.
- You'd need to run Prometheus + Grafana + exporter(s) somewhere — minimum a small VPS, realistically 1–2GB RAM comfortably, plus you own upgrades/storage retention/security.

**Where it *does* make sense for you**
- You already mentioned Datadog/Grafana+Loki/OpenTelemetry at FanDuel — if the appeal is "I know this stack, I want it on my own project," that's a legit reason, not really a cost/efficiency one.
- Grafana alone (no Prometheus) is genuinely useful: it can query **CloudWatch directly** as a data source, so you get CloudFront/S3 dashboards without running Prometheus at all. Grafana Cloud has a free tier (10k series, 14-day retention) that covers a personal site easily.

**Realistic setup if you still want this stack**
- Grafana Cloud free tier + CloudWatch data source plugin → dashboards on CloudFront requests/errors/bytes, zero infra to run.
- Skip Prometheus entirely unless you specifically want to practice/showcase it — it adds a scrape target problem you'd be solving artificially rather than one that exists here.
- For actual visitor analytics (page views, geography, referrers), pair this with Umami/Plausible as before — Grafana+CloudWatch tells you infra health, not who's reading your blog.

So: **Grafana yes, Prometheus probably not**, unless the goal is portfolio/practice value rather than the cheapest path to insight.