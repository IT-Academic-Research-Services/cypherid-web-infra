locals {
  env_seqtoid_org_url = "https://${data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn}"
}

# The inline `acl`, `acceleration_status`, `versioning`,
# `server_side_encryption_configuration`, `lifecycle_rule`, and `cors_rule`
# sub-arguments of `aws_s3_bucket` were deprecated in the AWS provider v4 and
# moved to dedicated `aws_s3_bucket_*` resources (removed in a future major).
# They are split out below (#475). Splitting an inline block into its standalone
# resource is apply-safe: the bucket is not recreated, so no `moved {}` blocks
# are required. `versioning` on `samples` was already externalized to
# `aws_s3_bucket_versioning.samples`, so the (conflicting, superseded) inline
# `versioning { enabled = false }` is simply dropped rather than duplicated.

resource "aws_s3_bucket" "samples" {
  bucket        = var.s3_bucket_samples
  force_destroy = contains(["dev", "sandbox"], var.env)

  tags = {
    terraform = true
  }
}

resource "aws_s3_bucket" "samples_v1" {
  bucket        = var.s3_bucket_samples_v1
  force_destroy = contains(["dev", "sandbox"], var.env)

  tags = {
    terraform = true
  }
}

# The aws_s3_bucket_acl "private" resources for samples / samples_v1 were REMOVED: S3 disables
# ACLs by default (ObjectOwnership = BucketOwnerEnforced) since April 2023, so PutBucketAcl now
# fails outright (400 InvalidArgument) and took the whole db stack's apply down. A "private"
# canned ACL was always a no-op on these buckets -- they are private by default and access is
# governed by the bucket policy / IAM. Same fix as ecs/aegea-ecs-execute. See #687.

resource "aws_s3_bucket_accelerate_configuration" "samples" {
  bucket = aws_s3_bucket.samples.id
  status = "Enabled"
}

resource "aws_s3_bucket_accelerate_configuration" "samples_v1" {
  bucket = aws_s3_bucket.samples_v1.id
  status = "Enabled"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "samples" {
  bucket = aws_s3_bucket.samples.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "samples_v1" {
  bucket = aws_s3_bucket.samples_v1.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "samples" {
  bucket = aws_s3_bucket.samples.id

  rule {
    id     = "Abort Incomplete Multipart Uploads"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "Expiration"
    status = "Enabled"
    filter {
      prefix = "samples/"
    }
    expiration {
      # Short period is safer for data privacy.
      days = 30 # TODO: was 3, but hard to debug when files disappear
    }
  }

  rule {
    id     = "Expire Samples in 3 days"
    status = "Enabled"
    filter {
      prefix = "samples/"
    }

    tags = {
      "type" = "sample"
    }

    expiration {
      days = 3
    }
  }

  rule {
    id     = "Expire intermediate output files"
    status = "Enabled"
    filter {
      tag {
        key   = "intermediate_output"
        value = "true"
      }
    }
    expiration {
      days = 30 # TODO: was 1, but hard to debug when files disappear
    }
  }

  rule {
    id     = "Clade Exports Expiration"
    status = "Enabled"
    filter {
      prefix = "clade_exports/"
    }
    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "samples_v1" {
  bucket = aws_s3_bucket.samples_v1.id

  rule {
    id     = "Expiration"
    status = "Enabled"
    filter {
      prefix = "samples/"
    }
    expiration {
      days = 180
    }
  }

  rule {
    id     = "Clade Exports Expiration"
    status = "Enabled"
    filter {
      prefix = "clade_exports/"
    }
    expiration {
      days = 1
    }
  }

  rule {
    id     = "Abort Incomplete Multipart Uploads"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "samples" {
  bucket = aws_s3_bucket.samples.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE"]
    allowed_origins = [local.env_seqtoid_org_url]
    expose_headers  = ["ETag", "x-amz-checksum-sha256"]
  }

  // For Nextclade integration via presigned links. This allows us to use both the latest and v2 of Nextclade Web
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["https://clades.nextstrain.org", "https://v2.clades.nextstrain.org"]
  }
}

resource "aws_s3_bucket_cors_configuration" "samples_v1" {
  bucket = aws_s3_bucket.samples_v1.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE"]
    allowed_origins = [local.env_seqtoid_org_url]
  }

  // For Nextclade integration via presigned links. This allows us to use both the latest and v2 of Nextclade Web
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["https://clades.nextstrain.org", "https://v2.clades.nextstrain.org"]
  }
}

# samples versioning is managed by aws_s3_bucket_versioning.samples below
# (the inline `versioning { enabled = false }` was superseded by this and dropped).
resource "aws_s3_bucket_versioning" "samples" {
  bucket = aws_s3_bucket.samples.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "samples_v1" {
  bucket = aws_s3_bucket.samples_v1.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "samples" {
  bucket                  = aws_s3_bucket.samples.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "samples_v1" {
  bucket                  = aws_s3_bucket.samples_v1.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
