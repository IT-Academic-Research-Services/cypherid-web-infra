locals {
  s3_bucket_workflows = "seqtoid-workflows-${var.env}-${var.aws_accounts.idseq-staging}"

  zone_id      = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id
  env_fqdn     = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  www_env_fqdn = "www.${local.env_fqdn}"
}

data "aws_iam_policy_document" "idseq-web-assume-role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com", "ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "idseq-web" {
  name               = "idseq-web-${var.env}"
  description        = "task role for idseq-web task in ${var.env} environment"
  assume_role_policy = data.aws_iam_policy_document.idseq-web-assume-role.json
}

# Attaching these permissions for the SSRF protections provided by ssrfs-up.
# The policy "ssrfs-up-invoke" is added to the baseline so all accounts have
# access to it.
# https://github.com/chanzuckerberg/SSRFs-Up
data "aws_caller_identity" "current" {}
# resource "aws_iam_role_policy_attachment" "ssrfs-invoke" {
#   role       = aws_iam_role.idseq-web.name
#   policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ssrfs-up-invoke"
# }

data "aws_iam_policy_document" "idseq-web" {
  statement {
    actions = [
      "autoscaling:*",
      "batch:*",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:PutMetricData",
      "iam:List*",
      "iam:Get*",
      "iam:PassRole",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:PutLogEvents",
      "logs:TestMetricFilter",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeInstances",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribePlacementGroups",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotInstanceRequests",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcClassicLink",
      "ec2:TerminateInstances",
      "ecs:Describe*",
      "ecs:List*",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "elasticloadbalancing:Describe*",
      "es:*",
      "glue:GetJobRun",
      "glue:GetJobRuns",
      "glue:StartJobRun",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:GetAccelerateConfiguration",
    ]

    resources = [
      "arn:aws:s3:::seqtoid-sandbox",
      "arn:aws:s3:::${var.s3_bucket_samples}",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}",
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}",
      "arn:aws:s3:::${local.s3_bucket_workflows}",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::seqtoid-sandbox/*",
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}/*",
      "arn:aws:s3:::${local.s3_bucket_workflows}/*",
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}/*",
    ]
  }

  statement {
    actions = [
      "states:Describe*",
      "states:Get*",
      "states:List*",
      "states:StartExecution",
      "states:StopExecution",
    ]

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:ListQueues",
    ]

    resources = [
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-${var.env}-*",
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-swipe-${var.env}-*",
    ]
  }

  statement {
    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:*"
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-web" {
  name   = "idseq-web-${var.env}"
  role   = aws_iam_role.idseq-web.id
  policy = data.aws_iam_policy_document.idseq-web.json
}

# data "aws_iam_role" "poweruser" {
#   name = "poweruser"
# }

data "aws_iam_policy_document" "idseq-upload-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    sid     = "WebAssumeRole"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.idseq-web.arn]
    }
  }
  # statement {
  #   actions = ["sts:AssumeRole"]
  #   effect  = "Allow"
  #   sid     = "PowerUserAssumeRoleForDevEnvironments"

  #   principals {
  #     type        = "AWS"
  #     identifiers = [data.aws_iam_role.poweruser.arn]
  #   }
  # }
}

resource "aws_iam_role" "idseq-upload" {
  name               = "idseq-upload-${var.env}"
  description        = "role for users to assume to upload samples to the ${var.env} environment"
  assume_role_policy = data.aws_iam_policy_document.idseq-upload-assume-role.json
}

data "aws_iam_policy_document" "idseq-upload" {
  statement {
    sid    = "AllowSampleUploads"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/samples/*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-upload" {
  name   = "idseq-upload-${var.env}"
  role   = aws_iam_role.idseq-upload.id
  policy = data.aws_iam_policy_document.idseq-upload.json
}

module "parameters-policy" {
  source = "github.com/chanzuckerberg/cztack//aws-params-reader-policy?ref=v0.104.2"

  project   = var.project
  env       = var.env
  service   = var.component
  region    = var.region
  role_name = aws_iam_role.idseq-web.name
}

resource "random_string" "secret_key_base" {
  length    = 32
  special   = false
  min_lower = 8
  min_upper = 8
  # min_digits = 8
  # min_special = 8
}

module "web-service-params" {
  source  = "github.com/chanzuckerberg/cztack//aws-ssm-params-writer?ref=v0.104.2"
  project = var.project
  env     = var.env
  service = var.component
  owner   = var.owner

  parameters = {
    RDS_ADDRESS                    = data.terraform_remote_state.db.outputs.db_instance_address
    DB_PORT                        = data.terraform_remote_state.db.outputs.db_instance_port
    DB_USERNAME                    = data.terraform_remote_state.db.outputs.db_instance_username
    REDISCLOUD_URL                 = "rediss://${data.terraform_remote_state.redis.outputs.primary_endpoint_address}:6379"
    SAMPLES_BUCKET_NAME            = data.terraform_remote_state.db.outputs.samples_bucket
    SAMPLES_BUCKET_NAME_V1         = data.terraform_remote_state.db.outputs.samples_bucket_v1
    ALIGNMENT_CONFIG_DEFAULT_NAME  = var.alignment_index_date
    ES_ADDRESS                     = "https://${data.terraform_remote_state.heatmap-optimization.outputs.elastic_search_endpoint}"
    CLOUDFRONT_ENDPOINT            = local.assets_fqdn
    CZID_CLOUDFRONT_ENDPOINT       = local.assets_fqdn
    S3_DATABASE_BUCKET             = var.s3_bucket_public_references
    CLI_UPLOAD_ROLE_ARN            = aws_iam_role.idseq-upload.arn
    SECRET_KEY_BASE                = random_string.secret_key_base.result
    SERVER_DOMAIN                  = "https://${data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn}"
    GRAPHQL_FEDERATION_SERVICE_URL = "https://${data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn}/graphqlfed"
    S3_AEGEA_ECS_EXECUTE_BUCKET    = var.s3_bucket_aegea_ecs_execute
    AUTO_ACCOUNT_CREATION_V1       = 1
    S3_WORKFLOWS_BUCKET            = local.s3_bucket_workflows
    LAMBDA_ENV                     = var.env # TODO: Only necessary for dev, as it defaults to Rails.env ('development') in the code
  }
}

module "staging" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.104.2"

  cert_domain_name    = local.env_fqdn
  aws_route53_zone_id = local.zone_id
  tags                = var.tags # TODO: var.tags is deprecated

  cert_subject_alternative_names = {
    (local.www_env_fqdn) = local.zone_id
  }
}

module "staging_east" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.104.2"

  cert_domain_name    = local.env_fqdn
  aws_route53_zone_id = local.zone_id
  tags                = var.tags # TODO: var.tags is deprecated

  cert_subject_alternative_names = {
    (local.www_env_fqdn) = local.zone_id
  }

  # cloudfront requires us-east-1 acm certs
  providers = {
    aws = aws.us-east-1
  }
}

module "web-service" {
  source = "../../../modules/ecs-service-with-alb-v0.421.0"

  service             = "web"
  project             = var.project
  owner               = var.owner
  container_port      = 3000
  container_name      = "rails"
  env                 = var.env
  vpc_id              = data.terraform_remote_state.cloud-env.outputs.vpc_id
  cluster_id          = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn       = aws_iam_role.idseq-web.arn
  desired_count       = 1
  lb_subnets          = data.terraform_remote_state.cloud-env.outputs.public_subnets
  route53_zone_id     = local.zone_id
  subdomain           = ""
  health_check_path   = "/health_check"
  acm_certificate_arn = module.staging.arn
  lb_egress_cidrs     = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  access_logs_bucket  = data.terraform_remote_state.elb-access-logs.outputs.bucket_name

  # The AWS and module default is 60s. We decided to increase it after observing
  # multiple endpoints exceeding that in production under normal loads, including
  # bulk_upload_with_metadata and report_csv.
  lb_idle_timeout_seconds = 300
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

resource "aws_route53_record" "www" {
  zone_id = local.zone_id
  name    = local.www_env_fqdn
  type    = "A"

  alias {
    name                   = module.web-service.alb_dns_name
    zone_id                = module.web-service.alb_route53_zone_id
    evaluate_target_health = false
  }
}

resource "aws_ecr_repository" "web-repository" {
  name                 = "idseq-web"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "idseq-web" {
  repository = aws_ecr_repository.web-repository.name

  policy = jsonencode({
    rules = [
      {
        action = {
          type = "expire"
        },
        selection : {
          countType     = "imageCountMoreThan",
          countNumber   = 1,
          tagStatus     = "tagged",
          tagPrefixList = ["latest"],
        },
        description    = "Always keep the one image tagged as latest (there should only be one). \"An image that matches the tagging requirements of a rule cannot be expired by a rule with a lower priority.\"",
        "rulePriority" = 1
      },
      {
        rulePriority = 2,
        description  = "Remove all images after 365 days (except for the image tagged \"latest\")",
        selection = {
          tagStatus   = "any",
          countType   = "sinceImagePushed",
          countUnit   = "days",
          countNumber = 365
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
