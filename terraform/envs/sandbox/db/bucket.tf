resource "aws_s3_bucket" "samples" {
  bucket              = var.s3_bucket_samples
  acl                 = "private"
  acceleration_status = "Enabled"

  versioning {
    enabled = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id                                     = "Abort Incomplete Multipart Uploads"
    enabled                                = true
    prefix                                 = ""
    abort_incomplete_multipart_upload_days = 7
  }

  lifecycle_rule {
    id      = "Expiration"
    enabled = true
    prefix  = "samples/"

    expiration {
      // Short period is safer for data privacy.
      days = 3
    }
  }

  lifecycle_rule {
    id      = "Expire intermediate output files"
    enabled = true
    prefix  = "samples/"

    tags = {
      intermediate_output = "true"
    }

    expiration {
      days = 1
    }
  }

  lifecycle_rule {
    id      = "Clade Exports Expiration"
    enabled = true
    prefix  = "clade_exports/"

    expiration {
      days = 1
    }
  }

  tags = {
    env       = var.env
    terraform = true
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE"]
    allowed_origins = ["https://${var.env}.idseq.net", "https://${var.env}.czid.org", "https://${var.env}.ucsf.czid.org"]
    expose_headers  = ["ETag", "x-amz-checksum-sha256"]
  }

  // For Nextclade integration via presigned links. This allows us to use both the latest and v2 of Nextclade Web
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["https://clades.nextstrain.org", "https://v2.clades.nextstrain.org"]
  }
}

resource "aws_s3_bucket" "samples_v1" {
  bucket              = var.s3_bucket_samples_v1
  acl                 = "private"
  acceleration_status = "Enabled"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "Expiration"
    enabled = true
    prefix  = "samples/"

    expiration {
      days = 180
    }
  }

  lifecycle_rule {
    id      = "Clade Exports Expiration"
    enabled = true
    prefix  = "clade_exports/"

    expiration {
      days = 1
    }
  }

  lifecycle_rule {
    id                                     = "Abort Incomplete Multipart Uploads"
    enabled                                = true
    prefix                                 = ""
    abort_incomplete_multipart_upload_days = 7
  }

  tags = {
    env       = var.env
    terraform = true
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "DELETE"]
    allowed_origins = ["https://staging.idseq.net", "https://${var.env}.czid.org", "https://${var.env}.ucsf.czid.org"]
  }

  // For Nextclade integration via presigned links. This allows us to use both the latest and v2 of Nextclade Web
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["https://clades.nextstrain.org", "https://v2.clades.nextstrain.org"]
  }
}
