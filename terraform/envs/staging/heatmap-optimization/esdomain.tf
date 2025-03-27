resource "aws_cloudwatch_log_group" "elasticsearch-log-publishing-policy" {
  name = "${var.env}-elasticsearch-log-publishing-policy"
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
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/aws-elasticsearch?ref=v0.199.1"

  project = "czid"
  env     = var.env
  service = local.service
  owner   = var.owner

  domain_name = "czid-${var.env}-heatmap-es"

  instance_type         = "m6g.large.elasticsearch"
  instance_count        = 4
  ebs_volume_type       = "gp3"
  ebs_volume_size       = 32
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
