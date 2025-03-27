resource "aws_s3_bucket" "monorepo-tfstate" {
  bucket = "tfstate-${var.aws_accounts["idseq-prod"]}"
  acl    = "private"

  versioning {
    enabled    = true
    mfa_delete = false
  }

  tags = {
    env     = "prod"
    owner   = "biohub-tech@chanzuckerberg.com"
    project = "idseq"
    service = "idseq"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
