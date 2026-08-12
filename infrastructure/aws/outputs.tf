output "iam_user_name" {
  description = "IAM user used by local Grafana and clickhouse-local."
  value       = aws_iam_user.observability_readonly.name
}

output "iam_user_arn" {
  value = aws_iam_user.observability_readonly.arn
}

output "access_key_id" {
  description = "Access key ID — copy into infrastructure/local/.env as AWS_ACCESS_KEY_ID."
  value       = aws_iam_access_key.observability_readonly.id
}

output "secret_access_key" {
  description = "Secret access key — copy into infrastructure/local/.env as AWS_SECRET_ACCESS_KEY. Shown once; store securely."
  value       = aws_iam_access_key.observability_readonly.secret
  sensitive   = true
}

output "cf_access_logs_bucket_name" {
  value = var.cf_access_logs_bucket_name
}
