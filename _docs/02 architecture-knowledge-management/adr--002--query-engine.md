# ADR-002: Use clickhouse-local (not Athena) for Phase 0 CloudFront log queries

## Status
Accepted

## Date
2026-08-12

## Context

Phase 0 needs ad-hoc SQL over CloudFront standard access logs stored in S3 (`cf-access-logs.paulserban.eu`), with a hard constraint of **$0 hosting** and local-only tooling. Two options were evaluated:

1. **Amazon Athena** (+ Glue catalog / table over the log bucket) — the original deliverable in `01 - phased-plan.md`
2. **clickhouse-local** querying gzipped logs via the `s3()` table function — recommended in spike [`04 - adding-clickhouse.md`](../01%20spikes/04%20-%20adding-clickhouse.md)

## Decision

Use **clickhouse-local** (via Docker, no local binary install) as the Phase 0 query engine over CloudFront access logs. Do **not** stand up Athena or a Glue catalog for this phase.

## Rationale

- **Same $0 / local-only constraint:** Athena is pay-per-query (pennies at this volume) but still requires Glue table setup and an AWS console/SQL workflow. `clickhouse-local` runs on the laptop with zero AWS analytics services.
- **Real SQL engine, transferable skills:** queries are ordinary ClickHouse SQL; skills carry over if ClickHouse is ever used elsewhere (e.g. optional Umami backend swap at higher traffic).
- **Operational simplicity:** one wrapper script (`infrastructure/local/scripts/query.sh`) + saved `.sql` files; no catalog to keep in sync when prefixes/domains change.
- **Already validated:** top-paths / status-breakdown / cache-hit-ratio queries return real results against live log objects shortly after logging was enabled.

## Alternatives Considered

| Option                                     | Rejected because                                                                                                                       |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Athena + Glue                              | Extra AWS surface (catalog, workgroup, per-query billing) for no capability Phase 0 needs; colder start UX for interactive exploration |
| Always-on ClickHouse server on a VPS       | Out of scope for Phase 0; would duplicate Prometheus/Loki later and add RAM pressure on a budget VPS                                   |
| AWS Console log browsing / S3 Select alone | Not reproducible from a clean laptop as a saved query workflow                                                                         |

## Consequences

- **Positive:** Phase 0 exit gate ("top 10 paths and error rate, last 7 days") is met without Athena; README Getting Started points at clickhouse-local for CLI SQL.
- **Negative:** Athena is no longer the documented primary path — anyone following the older phased-plan wording literally would be out of date (this ADR + README supersede that detail for Phase 0).
- **Grafana log UI:** Interactive access-log dashboards use **Loki + Alloy** (Phase 6 practiced locally), not a persistent ClickHouse server or Grafana ClickHouse plugin. clickhouse-local remains CLI-only.
- **Revisit trigger:** If query volume or multi-user shared SQL over the same log lake becomes a requirement, or if clickhouse-local S3 access patterns become awkward, reconsider Athena as a serverless shared query layer.
