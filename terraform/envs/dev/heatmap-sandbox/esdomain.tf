# Sandbox heatmap OpenSearch domain.
#
# This is a SECOND, isolated OpenSearch domain (czid-sandbox-heatmap-es) that lives in the SAME dev
# account + dev VPC as the dev heatmap domain, but is dedicated to the per-PR preview sandboxes
# (seqtoid-pr-N namespaces on czid-dev-eks-v2). Preview sandboxes are namespaces INSIDE the dev
# account/VPC -- not a separate fogg env -- so their isolated domain is a dev-account component here
# that reads the dev cloud-env remote state for the VPC/subnets.
#
# Why: sandboxes run regular-cadence, potentially-destructive taxon indexing (index recreate, alias
# swap, delete_by_query eviction). Sharing dev's czid-dev-heatmap-es risked a bad sandbox op damaging
# dev's heatmap + taxon-search data. This domain gives all sandboxes ONE shared sandbox tier
# (Tom, 2026-07-19), isolated from dev, at ~1 extra t3.small x2 domain.
#
# Everything below mirrors dev/heatmap-optimization/esdomain.tf but is named off local.tier
# ("sandbox") instead of var.env ("dev") so nothing collides with the dev domain's resources.

# CZID-63: customer-managed KMS key encrypting the Elasticsearch log-publishing group.
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "elasticsearch_logs_kms" {
  #checkov:skip=CKV_AWS_111:key policy resource is implicitly the key itself; cannot scope
  #checkov:skip=CKV_AWS_356:key policy resource is implicitly the key itself; cannot scope
  #checkov:skip=CKV_AWS_109:root kms:* is the required lockout-prevention grant for a CMK
  statement {
    sid       = "RootAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.tier}-elasticsearch-log-publishing-policy"]
    }
  }
}

resource "aws_kms_key" "elasticsearch_logs" {
  description             = "${local.tier}-elasticsearch log group encryption (CZID-63)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.elasticsearch_logs_kms.json
}

resource "aws_cloudwatch_log_group" "elasticsearch-log-publishing-policy" {
  name              = "${local.tier}-elasticsearch-log-publishing-policy"
  retention_in_days = 365                                # >= 1yr (CKV_AWS_338)
  kms_key_id        = aws_kms_key.elasticsearch_logs.arn # CMK-encrypted (CKV_AWS_158)
}


data "aws_iam_policy_document" "elasticsearch-log-publishing-policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = ["arn:aws:logs:*"]

    principals {
      identifiers = ["es.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "elasticsearch-log-publishing-policy" {
  policy_document = data.aws_iam_policy_document.elasticsearch-log-publishing-policy.json
  policy_name     = "${local.tier}-elasticsearch-log-publishing-policy"
}


module "elasticsearch" {
  source = "../../../modules/aws-elasticsearch-v0.199.1"

  project = "czid"
  env     = local.tier
  service = local.service
  owner   = var.owner

  domain_name = "czid-${local.tier}-heatmap-es"

  instance_type         = var.es_instance_type
  instance_count        = var.es_instance_count
  ebs_volume_type       = var.es_ebs_volume_type
  ebs_volume_size       = var.es_ebs_volume_size
  elasticsearch_version = "OpenSearch_2.7"
  log_publishing_options = {
    cloudwatch_log_group = aws_cloudwatch_log_group.elasticsearch-log-publishing-policy.arn
  }

  vpc_subnet_ids = [
    data.terraform_remote_state.cloud-env.outputs.private_subnets[0],
    data.terraform_remote_state.cloud-env.outputs.private_subnets[1],
  ]

  vpc_id        = data.terraform_remote_state.cloud-env.outputs.vpc_id
  ingress_cidrs = data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block
  egress_cidrs  = data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block
}
