# CZID-61 (#61): a private S3 bucket configured to receive CloudFront standard (legacy) access logs,
# plus the log-delivery ACL grant CloudFront requires. Callers reference bucket_domain_name in the
# distribution's logging_config to satisfy checkov CKV_AWS_86 (access logging enabled).
#
# WHY A GRANT + BucketOwnerPreferred: CloudFront *standard* logging writes via the S3 ACL system — the
# bucket must have ACLs enabled (object_ownership = BucketOwnerPreferred) and grant the CloudFront
# "awslogsdelivery" canonical user FULL_CONTROL. (This is the legacy logging mechanism used by the
# existing distributions' logging_config argument; the newer log-delivery-service flow is a separate,
# larger change and out of scope for this hardening slice.)
#
# The bucket name is derived from the account id so it is deterministic and globally unique per env —
# no hardcoded/ops-gated placeholder name.

data "aws_caller_identity" "current" {}

# The bucket-owner grant below needs the S3 CANONICAL USER ID (64-char hex) -- NOT the 12-digit
# account id. Passing the account id as a CanonicalUser grantee makes S3 reject the whole
# PutBucketAcl with InvalidArgument, which failed the entire dev/web apply.
data "aws_canonical_user_id" "current" {}

locals {
  # CloudFront standard-logging delivery canonical user (global, AWS-published constant).
  cloudfront_log_delivery_canonical_id = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"

  bucket_name = substr("cloudfront-access-logs-${var.tags.project}-${var.tags.env}-${var.tags.service}-${data.aws_caller_identity.current.account_id}", 0, 63)
}

module "logs_bucket" {
  source        = "../aws-s3-private-bucket-v0.104.2" # cztack v0.104.2
  project       = var.tags.project
  env           = var.tags.env
  service       = var.tags.service
  owner         = var.tags.owner
  bucket_name   = local.bucket_name
  force_destroy = var.force_destroy

  # CloudFront standard logging writes via ACLs; enable ownership controls + grant the CloudFront
  # log-delivery canonical user + the bucket owner FULL_CONTROL.
  object_ownership = "BucketOwnerPreferred"
  grants = [
    {
      canonical_user_id = local.cloudfront_log_delivery_canonical_id
      permissions       = ["FULL_CONTROL"]
    },
    {
      canonical_user_id = data.aws_canonical_user_id.current.id
      permissions       = ["FULL_CONTROL"]
    },
  ]

  lifecycle_rules = [
    {
      id      = "expire-cloudfront-access-logs"
      enabled = true
      expiration = {
        days = var.log_retention_days
      }
      prefix = ""
    }
  ]
}
