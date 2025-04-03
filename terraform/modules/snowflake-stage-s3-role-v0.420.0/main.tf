locals {
  name = "${var.project}-${var.env}-${var.service}"

  tags = {
    managedBy = "terraform"
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
  }
}

data "aws_iam_policy_document" "snowflake-assume" {
  statement {
    sid     = "EnableSnowflakeAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.aws_iam_principal]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = var.external_ids
    }
  }
}

resource "aws_iam_role" "snowflake" {
  name                 = "${local.name}-snowflake-ingest"
  assume_role_policy   = data.aws_iam_policy_document.snowflake-assume.json
  tags                 = local.tags
  max_session_duration = var.max_session_duration_seconds
}

module "aws-iam-policy-s3-reader" {
  source = "../aws-iam-policy-s3-reader"

  role_name     = aws_iam_role.snowflake.name
  bucket_name   = var.bucket_name
  bucket_prefix = var.bucket_prefix

  env     = var.env
  service = var.service
  owner   = var.owner
  project = var.project
}
