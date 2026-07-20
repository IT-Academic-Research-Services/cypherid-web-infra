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
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.env}-elasticsearch-log-publishing-policy"]
    }
  }
}

resource "aws_kms_key" "elasticsearch_logs" {
  description             = "${var.env}-elasticsearch log group encryption (CZID-63)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.elasticsearch_logs_kms.json
}

resource "aws_cloudwatch_log_group" "elasticsearch-log-publishing-policy" {
  name              = "${var.env}-elasticsearch-log-publishing-policy"
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
  policy_name     = "${var.env}-elasticsearch-log-publishing-policy"
}


module "elasticsearch" {
  source = "../../../modules/aws-elasticsearch-v0.199.1"

  project = "czid"
  env     = var.env
  service = local.service
  owner   = var.owner

  domain_name = "czid-${var.env}-heatmap-es"

  instance_type         = var.es_instance_type
  instance_count        = var.es_instance_count
  ebs_volume_type       = var.es_ebs_volume_type
  ebs_volume_size       = var.es_ebs_volume_size
  elasticsearch_version = "OpenSearch_2.7"

  # CZID-726: dedicated masters + Auto-Tune (see esdomain_sizing.tf for rationale/cost).
  dedicated_master_enabled = var.es_dedicated_master_enabled
  dedicated_master_type    = var.es_dedicated_master_type
  dedicated_master_count   = var.es_dedicated_master_count
  auto_tune_desired_state  = var.es_auto_tune_desired_state
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
