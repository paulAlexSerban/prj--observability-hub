variable "aws_region" {
  description = "AWS region for IAM resources. CloudWatch metrics for CloudFront are global; S3 log bucket lives in the site stack's primary region."
  type        = string
  default     = "eu-central-1"
}

variable "iam_user_name" {
  description = "IAM user name for local Phase 0 Grafana + clickhouse-local access."
  type        = string
  default     = "observability-hub-readonly"
}

variable "cf_access_logs_bucket_arn" {
  description = "ARN of the shared CloudFront access-log bucket (output from prj--personal-portfolio--v3 prod)."
  type        = string
  default     = "arn:aws:s3:::cf-access-logs.paulserban.eu"
}

variable "cf_access_logs_bucket_name" {
  description = "Name of the shared CloudFront access-log bucket."
  type        = string
  default     = "cf-access-logs.paulserban.eu"
}
