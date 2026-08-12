terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Local state for Phase 0 (single laptop). Migrate to S3+DynamoDB if a second
  # machine needs to apply this stack.
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = "prj--observability-hub"
    Environment = "phase-0-local"
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Read-only IAM user for local Grafana (CloudWatch) + clickhouse-local (S3)
# ---------------------------------------------------------------------------

resource "aws_iam_user" "observability_readonly" {
  name = var.iam_user_name
  path = "/observability/"
  tags = local.tags
}

data "aws_iam_policy_document" "observability_readonly" {
  statement {
    sid = "CloudWatchReadMetrics"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
    ]
    resources = ["*"]
  }

  # Grafana CloudWatch datasource also lists CloudFront distributions for the
  # Dimension dropdown when browsing the AWS/CloudFront namespace.
  statement {
    sid = "CloudFrontListDistributions"
    actions = [
      "cloudfront:ListDistributions",
      "cloudfront:GetDistribution",
      "cloudfront:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "S3ListAccessLogBucket"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [var.cf_access_logs_bucket_arn]
  }

  statement {
    sid = "S3ReadAccessLogs"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${var.cf_access_logs_bucket_arn}/*"]
  }
}

resource "aws_iam_user_policy" "observability_readonly" {
  name   = "observability-readonly-cloudwatch-s3"
  user   = aws_iam_user.observability_readonly.name
  policy = data.aws_iam_policy_document.observability_readonly.json
}

resource "aws_iam_access_key" "observability_readonly" {
  user = aws_iam_user.observability_readonly.name
}
