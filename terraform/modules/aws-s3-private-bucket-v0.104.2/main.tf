locals {
  # If grants are defined, we use `grant` to grant permissions, otherwise it will use the `acl` to grant permissions
  acl = length(var.grants) == 0 ? var.acl : null

  # `canonical_user_id` and `uri` should be specified exclusively in each grant, so we skip the invalid inputs in grants
  # invalid input is the case that they are both or neither specified
  valid_grants = [for grant in var.grants : {
    canonical_user_id = lookup(grant, "canonical_user_id", null)
    uri               = lookup(grant, "uri", null)
    permissions       = grant.permissions
    } if !(
    (lookup(grant, "canonical_user_id", null) != null && lookup(grant, "uri", null) != null) ||
    (lookup(grant, "canonical_user_id", null) == null && lookup(grant, "uri", null) == null)
    )
  ]

  # The standalone aws_s3_bucket_acl grant block takes a SINGLE permission string,
  # unlike the deprecated inline aws_s3_bucket grant which took a permissions list.
  # Expand each grant into one (grantee, permission) pair per permission so a
  # multi-permission grant maps to one grant block each. Assigning the list
  # directly to permission fails: "string required, but have tuple".
  grant_permissions = flatten([
    for grant in local.valid_grants : [
      for permission in grant.permissions : {
        canonical_user_id = grant.canonical_user_id
        uri               = grant.uri
        permission        = permission
      }
    ]
  ])

  # S3 disabled ACLs by default (BucketOwnerEnforced) in April 2023. An ACL can only be PUT
  # when ownership is explicitly BucketOwnerPreferred/ObjectWriter. On an ACL-disabled bucket a
  # canned "private" ACL is a legacy no-op that AWS now REJECTS outright (PutBucketAcl -> 400
  # InvalidArgument), which fails the whole stack. Skip the ACL entirely in that case: the
  # bucket is private by default and access is governed by the bucket policy / IAM.
  acls_enabled = var.object_ownership != null && var.object_ownership != "BucketOwnerEnforced"

  tags = {
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
    managedBy = "terraform"
  }
}

# Needed as the bucket owner when defining an explicit grant-based ACL policy
# (the standalone aws_s3_bucket_acl resource requires an owner block).
data "aws_canonical_user_id" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = local.tags
}

# The inline `acl`/`grant`, `versioning`, `cors_rule`, `acceleration_status`,
# `lifecycle_rule`, and `logging` sub-arguments of `aws_s3_bucket` were
# deprecated in the AWS provider v4 and moved to dedicated resources
# (removed entirely in a future major). They are split out below. Migrating
# an inline block to its standalone resource is apply-safe: the S3 bucket is
# not recreated, so no `moved {}` blocks are required.

# `grant` and `acl` conflict with each other - https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#acl
# ACLs require object ownership other than BucketOwnerEnforced; the caller is
# responsible for setting var.object_ownership accordingly when using grants.
resource "aws_s3_bucket_acl" "bucket" {
  count = local.acls_enabled ? (length(local.valid_grants) == 0 ? (local.acl == null ? 0 : 1) : 1) : 0

  # The ownership controls must land BEFORE the ACL, or S3 still considers ACLs disabled.
  depends_on = [aws_s3_bucket_ownership_controls.bucket]

  bucket = aws_s3_bucket.bucket.id

  # Using a canned ACL conflicts with using grant ACLs, so they are mutually
  # exclusive (mirrors the original inline behavior driven by var.grants).
  acl = length(local.valid_grants) == 0 ? local.acl : null

  dynamic "access_control_policy" {
    for_each = length(local.valid_grants) == 0 ? [] : [1]

    content {
      dynamic "grant" {
        for_each = local.grant_permissions

        content {
          grantee {
            id   = grant.value.canonical_user_id
            uri  = grant.value.uri
            type = grant.value.canonical_user_id == null ? "Group" : "CanonicalUser"
          }
          permission = grant.value.permission
        }
      }

      owner {
        id = data.aws_canonical_user_id.current.id
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_cors_configuration" "bucket" {
  count = length(var.cors_rules) == 0 ? 0 : 1

  bucket = aws_s3_bucket.bucket.id

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      allowed_methods = lookup(cors_rule.value, "allowed_methods", null)
      allowed_origins = lookup(cors_rule.value, "allowed_origins", null)
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
}

resource "aws_s3_bucket_accelerate_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  status = var.transfer_acceleration ? "Enabled" : "Suspended"
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket" {
  #checkov:skip=CKV_AWS_300:every rule sets abort_incomplete_multipart_upload (days_after_initiation defaults to var.abort_incomplete_multipart_upload_days = 14); the block is dynamic so checkov's static scan cannot see it
  count = length(var.lifecycle_rules) == 0 ? 0 : 1

  bucket = aws_s3_bucket.bucket.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      # The provider REQUIRES rule[*].id ("Must set a configuration value for the rule[0].id
      # attribute"); passing null fails the plan outright for any caller that omits it, which
      # broke elb-access-logs + heatmap-optimization. Fall back to a stable index-based id.
      # Callers that DO set an id are unaffected. See platform-overhaul #687.
      id     = lookup(rule.value, "id", "lifecycle-rule-${rule.key}")
      status = lookup(rule.value, "enabled", false) ? "Enabled" : "Disabled"

      # `prefix` (and `tags`) moved under a `filter` block in the standalone
      # lifecycle resource. An empty filter matches all objects, preserving the
      # original behavior when no prefix/tags were supplied.
      filter {
        prefix = lookup(rule.value, "prefix", null)

        dynamic "tag" {
          for_each = lookup(rule.value, "tags", null) == null ? {} : rule.value.tags

          content {
            key   = tag.key
            value = tag.value
          }
        }
      }

      # var.abort_incomplete_multipart_upload_days is 14 by default
      abort_incomplete_multipart_upload {
        days_after_initiation = lookup(rule.value, "abort_incomplete_multipart_upload_days", var.abort_incomplete_multipart_upload_days)
      }

      dynamic "expiration" {
        for_each = length(keys(lookup(rule.value, "expiration", {}))) == 0 ? [] : [lookup(rule.value, "expiration", {})]

        content {
          date                         = lookup(expiration.value, "date", null)
          days                         = lookup(expiration.value, "days", null)
          expired_object_delete_marker = lookup(expiration.value, "expired_object_delete_marker", null)
        }
      }

      dynamic "transition" {
        for_each = length(keys(lookup(rule.value, "transition", {}))) == 0 ? [] : [lookup(rule.value, "transition", {})]

        content {
          date          = lookup(transition.value, "date", null)
          days          = lookup(transition.value, "days", null)
          storage_class = lookup(transition.value, "storage_class", null)
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = length(keys(lookup(rule.value, "noncurrent_version_expiration", {}))) == 0 ? [] : [lookup(rule.value, "noncurrent_version_expiration", {})]

        content {
          noncurrent_days = lookup(noncurrent_version_expiration.value, "days", null)
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = length(keys(lookup(rule.value, "noncurrent_version_transition", {}))) == 0 ? [] : [lookup(rule.value, "noncurrent_version_transition", {})]

        content {
          noncurrent_days = lookup(rule.value.noncurrent_version_transition, "days", null)
          storage_class   = lookup(rule.value.noncurrent_version_transition, "storage_class", null)
        }
      }
    }
  }
}

resource "aws_s3_bucket_logging" "bucket" {
  count = var.logging_bucket == null ? 0 : 1

  bucket        = aws_s3_bucket.bucket.id
  target_bucket = var.logging_bucket.name
  target_prefix = var.logging_bucket.prefix
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  count = var.public_access_block ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "bucket_policy" {
  # Deny access to bucket if it's not accessed through HTTPS
  source_policy_documents = var.bucket_policy == null || var.bucket_policy == "" ? [] : [var.bucket_policy]

  statement {
    sid     = "EnforceTLS"
    actions = ["*"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    effect = "Deny"

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json

  // It seems that running aws_s3_bucket_policy and aws_s3_bucket_public_access_block at the same time
  // causes problems
  // https://github.com/terraform-providers/terraform-provider-aws/issues/7628
  depends_on = [aws_s3_bucket_public_access_block.bucket]
}

resource "aws_s3_bucket_ownership_controls" "bucket" {
  count = var.object_ownership != null ? 1 : 0

  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_kms_key" "bucket_kms_key" {
  count = var.kms_encryption != null ? 1 : 0

  description              = "This key is used to encrypt bucket objects for bucket ${var.bucket_name}"
  customer_master_key_spec = var.kms_key_type
  tags = {
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
    bucket    = var.bucket_name
    managedBy = "terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_sse_encryption" {
  count = var.kms_encryption != null ? 0 : 1

  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_kms_encryption" {
  count = var.kms_encryption != null ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.bucket_kms_key[0].arn
      sse_algorithm     = "aws:kms"
    }
  }
}
