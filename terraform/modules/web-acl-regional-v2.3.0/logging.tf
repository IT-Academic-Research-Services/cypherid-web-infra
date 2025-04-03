resource "aws_wafv2_web_acl_logging_configuration" "regional" {
  log_destination_configs = [module.logs_bucket.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"
      condition {
        action_condition {
          action = "COUNT"
        }
      }
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}

data "aws_iam_account_alias" "current" {}
data "aws_caller_identity" "current" {}

locals {
  bucket_name   = substr("aws-waf-logs-${local.web_acl_name}", 0, 63)
  account_id    = data.aws_caller_identity.current.account_id
  account_alias = data.aws_iam_account_alias.current.account_alias
}

data "aws_iam_policy_document" "waf_logs" {
  statement {
    sid       = "WriteWAFLogs"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.bucket_name}/AWSLogs/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:logs:*:*:*",
      ]
    }
  }

  statement {
    sid       = "ReadBucketACL"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.bucket_name}"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:logs:*:*:*",
      ]
    }
  }
}

module "logs_bucket" {
  source        = "github.com/chanzuckerberg/cztack//aws-s3-private-bucket?ref=v0.54.0"
  project       = var.tags.project
  env           = var.tags.env
  service       = var.tags.service
  owner         = var.tags.owner
  bucket_name   = local.bucket_name
  bucket_policy = data.aws_iam_policy_document.waf_logs.json
  lifecycle_rules = [
    {
      id      = "Expire WAF Requests"
      enabled = true
      expiration = {
        days = var.log_retention_days
      }
      prefix = "AWSLogs/"
    }
  ]
}

# Caveat(aku): If teams start to require notifications to other endpoints,
#   Revise this resource rather than creating new ones. 
#   S3 Buckets only support a single notification configuration. 
resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = var.enable_panther_ingest ? 1 : 0
  bucket = module.logs_bucket.id

  topic {
    id            = "notify-panther-new-events"
    topic_arn     = module.panther-s3[0].topic_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "AWSLogs/"
  }
}
