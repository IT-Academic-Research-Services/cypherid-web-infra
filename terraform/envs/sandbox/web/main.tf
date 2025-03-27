locals {
  zone_id = data.terraform_remote_state.idseq-dev.outputs.sandbox_idseq_net_zone_id
}

data "aws_iam_policy_document" "idseq-web-assume-role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
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
resource "aws_iam_role_policy_attachment" "ssrfs-invoke" {
  role       = aws_iam_role.idseq-web.name
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ssrfs-up-invoke"
}

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
      "arn:aws:s3:::${var.s3_bucket_samples}",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}",
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}",
      "arn:aws:s3:::${var.s3_bucket_workflows}",
      # IDSEQ-2933 - Giving access to both buckets so migration will not causing disruption during the switch
      #              The following line can be removed after public references are fully migrated:
      "arn:aws:s3:::idseq-database",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
      "arn:aws:s3:::${var.s3_bucket_aegea_ecs_execute}/*",
      "arn:aws:s3:::${var.s3_bucket_workflows}/*",
      # IDSEQ-2933 - Giving access to both buckets so migration will not causing disruption during the switch
      #              The following line can be removed after public references are fully migrated:
      "arn:aws:s3:::idseq-database/*",
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
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-dev-*",
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-${var.env}-*",
      "arn:aws:sqs:us-west-2:${data.aws_caller_identity.current.account_id}:idseq-swipe-dev-*",
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

data "aws_iam_role" "poweruser" {
  name = "poweruser"
}

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
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    sid     = "PowerUserAssumeRoleForDevEnvironments"

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.poweruser.arn]
    }
  }
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
      // allows sandbox role to write to dev bucket for uploads
      "arn:aws:s3:::idseq-samples-development/samples/*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-upload" {
  name   = "idseq-upload-${var.env}"
  role   = aws_iam_role.idseq-upload.id
  policy = data.aws_iam_policy_document.idseq-upload.json
}

module "parameters-policy" {
  source = "github.com/chanzuckerberg/cztack//aws-params-reader-policy?ref=v0.41.0"

  project   = var.project
  env       = var.env
  service   = var.component
  region    = var.region
  role_name = aws_iam_role.idseq-web.name
}

module "web-service-params" {
  source  = "github.com/chanzuckerberg/cztack//aws-ssm-params-writer?ref=v0.41.0"
  project = var.project
  env     = var.env
  service = var.component
  owner   = var.owner

  parameters = {
    RDS_ADDRESS                   = data.terraform_remote_state.db.outputs.db_instance_address
    DB_PORT                       = data.terraform_remote_state.db.outputs.db_instance_port
    DB_USERNAME                   = data.terraform_remote_state.db.outputs.db_instance_username
    REDISCLOUD_URL                = "rediss://${data.terraform_remote_state.redis.outputs.elasticache_secure_dns_name}:6379"
    SAMPLES_BUCKET_NAME           = data.terraform_remote_state.db.outputs.samples_bucket
    SAMPLES_BUCKET_NAME_V1        = data.terraform_remote_state.db.outputs.samples_bucket_v1
    ALIGNMENT_CONFIG_DEFAULT_NAME = var.alignment_index_date
    ES_ADDRESS                    = "https://${data.terraform_remote_state.heatmap-optimization.outputs.elastic_search_endpoint}"
    CLOUDFRONT_ENDPOINT           = "assets.${var.env}.idseq.net"
    CZID_CLOUDFRONT_ENDPOINT      = local.czid_full_domain
    S3_DATABASE_BUCKET            = var.s3_bucket_public_references
    CLI_UPLOAD_ROLE_ARN           = aws_iam_role.idseq-upload.arn
  }
}
