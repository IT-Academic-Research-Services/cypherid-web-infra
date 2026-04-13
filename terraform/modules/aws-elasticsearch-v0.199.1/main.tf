locals {
  name = "${var.project}-${var.env}-${var.service}"

  tags = {
    managedBy = "terraform"
    Name      = local.name
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
  }

  log_publishing_options = [
    "ES_APPLICATION_LOGS",
    "INDEX_SLOW_LOGS",
    "SEARCH_SLOW_LOGS",
  ]
}

resource "aws_elasticsearch_domain" "es" {
  domain_name           = var.domain_name
  elasticsearch_version = var.elasticsearch_version

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  cluster_config {
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    zone_awareness_enabled = true
    zone_awareness_config {
      availability_zone_count = var.availability_zone_count
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
  }

  snapshot_options {
    automated_snapshot_start_hour = 3
  }

  vpc_options {
    security_group_ids = concat([module.es-sg.security_group_id], var.custom_sg_ids)
    subnet_ids         = var.vpc_subnet_ids
  }

  # dynamic block used instead of simply assigning a variable b/c log_publishing_options is configuration block
  dynamic "log_publishing_options" {
    for_each = toset(local.log_publishing_options)

    content {
      cloudwatch_log_group_arn = var.log_publishing_options.cloudwatch_log_group
      enabled                  = true
      log_type                 = log_publishing_options.value
    }
  }

  tags = local.tags
}

resource "aws_elasticsearch_domain_policy" "main" {
  domain_name     = aws_elasticsearch_domain.es.domain_name
  access_policies = data.aws_iam_policy_document.access_policies.json
}

data "aws_iam_policy_document" "access_policies" {
  statement {
    principals {
      type        = "AWS"
      identifiers = var.access_policy_arns
    }

    actions   = ["es:*"]
    resources = ["${aws_elasticsearch_domain.es.arn}/*"]
  }
}

module "es-sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "4.3.0"
  name        = var.domain_name
  description = "Security for Elastic Search domain"
  vpc_id      = var.vpc_id

  tags = local.tags

  ingress_cidr_blocks = [var.ingress_cidrs]
  egress_cidr_blocks  = [var.egress_cidrs]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}
