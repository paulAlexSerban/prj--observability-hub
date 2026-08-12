ClickHouse is a good fit — but only in specific spots, not as a blanket addition. Here's where it earns its place and where it'd just be redundant weight next to what you already have.

**Strong fit: Phase 0, querying CloudFront logs — replaces/complements Athena, still $0**

`clickhouse-local` runs as a single binary with no server to stand up, and its `s3()` table function can query gzipped CloudFront access logs directly from your S3 bucket with plain SQL — no Glue catalog, no Athena setup, no per-query AWS charge. For a personal-scale site this is arguably a cleaner fit for Phase 0 than Athena: same "$0, local machine only" constraint, but you get a real SQL engine instead of Athena's slower cold-start query model, and the skills transfer directly if you ever want ClickHouse elsewhere.

```sql
SELECT status, count() FROM s3(
  'https://your-bucket.s3.amazonaws.com/cf-logs/*.gz',
  'TSV'
) GROUP BY status
```

**Optional, deferred: Umami's backend (Phase 2)**

Umami v2 natively supports ClickHouse instead of Postgres for the events table — it's actually Umami's own recommendation once traffic gets large, because Postgres struggles with high-cardinality event data at scale. At your current traffic (personal portfolio + blog, three domains), Postgres is comfortably right-sized. I'd leave this as a documented future swap, not something to build now — same logic as the k8s decision: don't pay the complexity tax before the scale exists to justify it.

**Not recommended: a persistent ClickHouse server on the VPS**

Running ClickHouse as an always-on service just to have it would duplicate what Prometheus (metrics) and Loki (logs) already do in Phases 5–6, while adding real memory pressure — ClickHouse's baseline footprint (~1GB+) is heavier than Loki's on a VPS you're already sizing tightly at 2–4GB total. Adding it as a third overlapping system with no new capability isn't a good trade at this scale.

**Net recommendation:** add ClickHouse to Phase 0 as the query engine over CloudFront logs (instead of or alongside Athena), and note the Umami-backend swap as a documented "if traffic grows" option rather than a current deliverable. Want me to update the plan doc with that?