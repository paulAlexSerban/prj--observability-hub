**Analytics/tracking (privacy-friendly, cheap)**
- **Cloudflare Web Analytics** — free, no cookies, just a JS snippet. Works fine even though you're on CloudFront (it's just client-side).
- **Plausible** — self-hosted (~$0 on a cheap VPS) or hosted ($9/mo). Very light.
- **Umami** — self-hosted, free forever; Postgres/MySQL backend. Popular for exactly this stack.
- **GoatCounter** — free hosted tier or self-host, extremely lightweight, no cookie banner needed.



**Uptime/synthetic monitoring**
- **UptimeRobot** — free tier (50 monitors, 5 min interval) covers a personal/portfolio site easily.
- **Better Stack** free tier is also solid if you want status pages too.

**Error/perf telemetry for a static Astro site**
- Since there's no backend, "observability" here mostly means RUM (real user monitoring) + logs:
  - **Sentry** free tier for JS error tracking if you have any client-side interactivity/islands.
  - **web-vitals** npm package + beacon to a free endpoint (or Plausible/Umami custom events) for Core Web Vitals without a paid RUM tool.

**On the "cheap VPS" idea**
If you want a $4–6/mo VPS (Hetzner/Contabo/OVH), self-hosting **Umami or Plausible** there is the sweet spot — one small container gives you analytics for this site plus any others (blog.paulserban.eu, quiz.paulserban.eu) on one instance, and you own the data instead of sending it to a third party.

Recommendation for your setup: 
- **Umami self-hosted on a cheap VPS** (covers all three of your domains) 
- **CloudFront access logs to S3/Athena** for infra-level traffic data, both essentially free beyond the VPS cost.
