# AWS — Phase 0 read-only identity

Provisions a least-privilege IAM user for the local Grafana CloudWatch data source and clickhouse-local S3 queries.

The CloudFront access-log bucket itself is owned by `prj--personal-portfolio--v3` (prod). This stack only grants read access to it.

## Apply

```bash
cd infrastructure/aws
terraform init
terraform plan
terraform apply
terraform output -raw access_key_id
terraform output -raw secret_access_key
```

Copy the outputs into `../local/.env` (see `../local/.env.example`). Never commit `.env` or Terraform state if it contains secrets.

## Destroy (when rotating keys)

```bash
terraform destroy
```
