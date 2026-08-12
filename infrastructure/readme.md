# Infrastructure

| Path | Purpose |
| --- | --- |
| [`aws/`](aws/) | Phase 0 Terraform — read-only IAM user for Grafana CloudWatch + clickhouse-local S3 reads |
| [`local/`](local/) | Phase 0 local Docker Compose (Grafana) + clickhouse-local query scripts |

VPS / Traefik compose for later phases will land under `local/` (or a sibling `vps/` tree) when Phase 1 starts. CloudFront logging resources stay in `prj--personal-portfolio--v3`.
