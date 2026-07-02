locals {
  tags = {
    project   = var.project
    env       = var.env
    service   = var.component
    owner     = var.owner
    managedBy = "terraform"
  }
}

data "aws_region" "current" {}

module "images" {
  source = "../../../modules/machine-images"
}

######## Lambda NCBI copy tool
data "aws_iam_policy_document" "lambda_ncbi_copy_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_ncbi_copy_role" {
  name               = "lambda_ncbi_copy_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_ncbi_copy_role.json
}

data "aws_iam_policy_document" "lambda_ncbi_copy_role_policy" {
  statement {
    sid = "1"

    actions = [
      "batch:*",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:PutMetricData",
      "iam:List*",
      "iam:Get*",
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
    ]

    resources = ["*"]
  }

  # CZID-18 (least-privilege, low-risk slice): split iam:PassRole into its own statement and constrain
  # it with iam:PassedToService so this role can only hand roles to the COMPUTE services it actually
  # uses (Batch jobs run as ECS tasks; EC2 for the compute environment) — never to arbitrary services
  # (lambda, iam, etc.), which is the privilege-escalation surface. The service list is a safe superset
  # of actual usage, so it does not remove any pass the lambda performs. Tightening to named role ARNs
  # is the Access-Analyzer follow-up (#361). See IAM-LEAST-PRIVILEGE-2026-06-29.md.
  statement {
    sid     = "PassRoleToComputeOnly"
    actions = ["iam:PassRole"]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ecs-tasks.amazonaws.com",
        "batch.amazonaws.com",
        "ec2.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "lambda_ncbi_copy_role_policy" {
  name   = "lambda_ncbi_copy_role_policy"
  role   = aws_iam_role.lambda_ncbi_copy_role.id
  policy = data.aws_iam_policy_document.lambda_ncbi_copy_role_policy.json
}

resource "aws_lambda_function" "ncbi_copy_lambda" {
  filename         = "submit_batch_job.zip"
  function_name    = "submit_ncbi_copy_job"
  role             = aws_iam_role.lambda_ncbi_copy_role.arn
  handler          = "submit_batch_job.submit_ncbi_copy_job"
  source_code_hash = filebase64sha256("submit_batch_job.zip")
  runtime          = "python3.6"
  timeout          = "300"
}

######### AWS Batch

resource "aws_batch_job_queue" "idseq-himem" {
  name                 = "idseq-${var.env}-himem"
  state                = "ENABLED"
  priority             = 25
  compute_environments = [aws_batch_compute_environment.idseq_244GB_32CPU.arn]
}

resource "aws_batch_job_queue" "idseq-lomem" {
  name                 = "idseq-${var.env}-lomem"
  state                = "ENABLED"
  priority             = 25
  compute_environments = [aws_batch_compute_environment.idseq_122GB_16CPU.arn]
}

module "idseq-batch" {
  source      = "../../../modules/aws-iam-instance-profile-v0.104.2" # cztack v0.104.2
  name_prefix = "idseq-batch-${var.env}"
}

data "aws_iam_policy_document" "idseq-batch" {
  statement {
    sid = "1"

    actions = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_samples}",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
    ]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-batch" {
  name   = "idseq-batch-${var.env}"
  role   = module.idseq-batch.role_name
  policy = data.aws_iam_policy_document.idseq-batch.json
}

data "aws_iam_policy_document" "aws_batch_service_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_batch_service_role" {
  name               = "aws_batch_service_role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.aws_batch_service_role.json
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "random_id" "batch" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    # TODO(elopez): temporarily commenting out due to ECS metadata endpoint throttling
    # image_id          =  module.images.czi_amazon2_ecs[data.aws_region.current.name]
    security_group_id = data.terraform_remote_state.ecs.outputs.security_group_id
  }

  byte_length = 8
}

resource "aws_batch_compute_environment" "idseq_244GB_32CPU" {
  compute_environment_name = "idseq_${var.env}_244GB_32CPU_${random_id.batch.hex}"

  compute_resources {
    instance_role = module.idseq-batch.profile_arn

    instance_type = [
      "r5d.8xlarge",
    ]

    ec2_key_pair       = "idseq-${var.env}"
    max_vcpus          = 4096
    desired_vcpus      = 128
    min_vcpus          = 0
    security_group_ids = [random_id.batch.keepers.security_group_id]
    subnets            = data.terraform_remote_state.cloud-env.outputs.private_subnets
    type               = "EC2"
    tags               = local.tags

    # image_id           =  random_id.batch.keepers.image_id
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]

  lifecycle {
    ignore_changes = [
      compute_resources[0].desired_vcpus,
    ]
  }
}

resource "aws_batch_compute_environment" "idseq_122GB_16CPU" {
  compute_environment_name = "idseq_${var.env}_122GB_16CPU_${random_id.batch.hex}"

  compute_resources {
    instance_role = module.idseq-batch.profile_arn

    instance_type = [
      "r5d.4xlarge",
    ]

    ec2_key_pair       = "idseq-${var.env}"
    max_vcpus          = 1536
    desired_vcpus      = 128
    min_vcpus          = 0
    security_group_ids = [random_id.batch.keepers.security_group_id]
    subnets            = data.terraform_remote_state.cloud-env.outputs.private_subnets
    type               = "EC2"
    tags               = local.tags

    # image_id           =  random_id.batch.keepers.image_id
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]

  lifecycle {
    ignore_changes = [
      compute_resources[0].desired_vcpus,
    ]
  }
}
