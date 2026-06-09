locals {
  name        = "${var.project}-${var.env}-${var.service}"
  secret_name = var.secret_name

  tags = {
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
    managedBy = "terraform"
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "aws-ssm-role" {
  name = var.aws_ssm_iam_role_name
  tags = local.tags
}

data "aws_iam_policy_document" "assume-role" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.aws-ssm-role.arn]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = "aws-ssm-${local.name}"
  assume_role_policy = data.aws_iam_policy_document.assume-role.json
  path               = var.iam_path

  tags = merge(local.tags, {
    allowAwsSsmRoleAssume = "true"
  })
}

data "aws_kms_alias" "parameter_store_key" {
  name = "alias/${var.parameter_store_key_alias}"
}

data "aws_iam_policy_document" "role_policy" {
  statement {
    actions = [
      "ssm:GetParametersByPath",
    ]

    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${local.name}"]
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.parameter_store_key.target_key_arn]
  }
}

resource "aws_iam_role_policy" "policy" {
  name   = "${local.name}-parameter-policy"
  role   = aws_iam_role.role.name
  policy = data.aws_iam_policy_document.role_policy.json
}

resource "kubernetes_secret" "secret" {
  count = var.create_secret ? 1 : 0
  metadata {
    name      = coalesce(local.secret_name, "${local.name}-from-aws-param")
    namespace = var.namespace

    annotations = {
      "alpha.ssm.cmattoon.com/aws-param-name" = "/${local.name}"
      "alpha.ssm.cmattoon.com/aws-param-type" = "Directory"
      "alpha.ssm.cmattoon.com/aws-param-key"  = "alias/${var.parameter_store_key_alias}"
      "iam.amazonaws.com/role"                = aws_iam_role.role.arn
    }
  }

  // By default, terraform detects any difference to the secret data and displays it in the terraform plan.
  // Since the secret is being populated and managed by aws-ssm, we want to ignore_changes and not display
  // the secret data.
  lifecycle {
    ignore_changes = [data]
  }
}
