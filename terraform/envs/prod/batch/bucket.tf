resource "aws_s3_bucket" "pipeline_public_assets" {
  bucket = var.s3_bucket_pipeline_public_assets
  acl    = "public-read"

  versioning {
    enabled = true
  }

  tags = {
    env       = var.env
    terraform = "true"
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}
