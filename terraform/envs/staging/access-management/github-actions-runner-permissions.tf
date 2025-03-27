
module "czid_web_private_gh_actions_executor" {
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/aws-iam-role-github-action?ref=v0.199.1"

  tags = var.tags

  role = {
    name = "czid-${var.env}-gh-actions-executor"
  }
  authorized_github_repos = {
    chanzuckerberg : ["czid-web-private", "idseq"]
  }
}

resource "aws_iam_role_policy_attachment" "czid_ga_ci_cd" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = aws_iam_policy.czid_ci_cd.arn
}

resource "aws_iam_role_policy_attachment" "czid_ci_cd_ssm" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "czid_ci_cd_iam" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "czid_ci_cd_ec2" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "czid_ci_cd_lambda" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "czid_ci_cd_cloudwatch" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "czid_ci_cd_ecr" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_policy" "czid_ci_cd" {
  name   = "czid-${var.env}-ci-cd"
  policy = data.aws_iam_policy_document.ci_cd_policy_document.json
}

data "aws_iam_policy_document" "ci_cd_policy_document" {
  statement {
    actions = [
      "s3:List*",
      "s3:Get*"
    ]

    resources = [
      "arn:aws:s3:::idseq-public-references",
      "arn:aws:s3:::idseq-public-references/*",
      "arn:aws:s3:::czid-public-references",
      "arn:aws:s3:::czid-public-references/*",
      "arn:aws:s3:::idseq-database",
      "arn:aws:s3:::idseq-database/*",
      "arn:aws:s3:::aegea-batch-jobs-${var.aws_accounts["idseq-dev"]}",
      "arn:aws:s3:::aegea-batch-jobs-${var.aws_accounts["idseq-dev"]}/*",
      "arn:aws:s3:::idseq-${var.env}-*",
      "arn:aws:s3:::idseq-bench",
      "arn:aws:s3:::idseq-bench/*"
    ]
  }

  statement {
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:PutObject*"
    ]

    resources = [
      "arn:aws:s3:::idseq-samples-development",
      "arn:aws:s3:::idseq-samples-development/*",
      "arn:aws:s3:::idseq-samples-staging",
      "arn:aws:s3:::idseq-samples-staging/*",
      "arn:aws:s3:::idseq-workflows",
      "arn:aws:s3:::idseq-workflows/*",
      "arn:aws:s3:::tfstate-${var.aws_accounts["idseq-dev"]}",
      "arn:aws:s3:::tfstate-${var.aws_accounts["idseq-dev"]}/*",
      "arn:aws:s3:::idseq-dev-heatmap",
      "arn:aws:s3:::idseq-dev-heatmap/*",
      "arn:aws:s3:::idseq-${var.env}-heatmap",
      "arn:aws:s3:::idseq-${var.env}-heatmap/*"
    ]
  }

  statement {
    actions = [
      "batch:*",
      "events:*",
      "states:*"
    ]

    resources = ["*"]
  }

  statement {
    actions = ["lambda:*"]

    resources = [
      "arn:aws:lambda:*:${var.aws_accounts["idseq-dev"]}:function:idseq-*",
      "arn:aws:lambda:*:${var.aws_accounts["idseq-dev"]}:function:cloudwatch-alerting-*"
    ]
  }
  statement {
    actions = ["secretsmanager:*"]

    resources = [
    "arn:aws:secretsmanager:*:${var.aws_accounts["idseq-dev"]}:secret:idseq/*"]
  }
  statement {
    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${var.aws_accounts["idseq-dev"]}:role/idseq-dev-*",
      "arn:aws:iam::${var.aws_accounts["idseq-dev"]}:role/idseq-${var.env}-*",
      "arn:aws:iam::${var.aws_accounts["idseq-dev"]}:role/idseq-swipe-dev-*",
      "arn:aws:iam::${var.aws_accounts["idseq-dev"]}:role/idseq-swipe-${var.env}-*",
      "arn:aws:iam::${var.aws_accounts["idseq-dev"]}:role/idseq-web-*"
    ]
  }

  statement {
    actions = [
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CopyImage",
      "ec2:CreateImage",
      "ec2:CreateKeypair",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:DeregisterImage",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
      "ec2:GetPasswordData",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySnapshotAttribute",
      "ec2:RegisterImage",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]
  }

  statement {
    sid = "UpdateLaunchTemplatePermissions"

    actions = [
      "ec2:CreateLaunchTemplate*",
      "ec2:DescribeLaunchTemplate*",
      "ec2:DeleteLaunchTemplate*",
      "ec2:ModifyLaunchTemplate"
    ]

    resources = ["*"]
  }

  statement {
    actions = ["sqs:*"]

    resources = [
      "arn:aws:sqs:*:${var.aws_accounts["idseq-dev"]}:idseq-dev-*",
      "arn:aws:sqs:*:${var.aws_accounts["idseq-dev"]}:idseq-${var.env}-*",
      "arn:aws:sqs:*:${var.aws_accounts["idseq-dev"]}:idseq-swipe-*"
    ]
  }

  statement {
    actions = [
      "ssm:DescribeParameters"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:PutParameter"
    ]

    resources = [
      "arn:aws:ssm:*:${var.aws_accounts["idseq-dev"]}:parameter/idseq-dev-*",
      "arn:aws:ssm:*:${var.aws_accounts["idseq-dev"]}:parameter/idseq-${var.env}-*"
    ]
  }
  statement {
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:RunTask"
    ]

    resources = [
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:service/staging/*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:service/idseq-sandbox-ecs/*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:service/idseq-prod-ecs/*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:task-definition/idseq-sandbox-web:*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:task-definition/idseq-staging-web:*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:task-definition/idseq-prod-web:*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:task/idseq-sandbox-ecs/*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:task/staging/*",
      "arn:aws:ecs:*:${var.aws_accounts["idseq-dev"]}:task/idseq-prod-ecs/*"
    ]
  }

  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]

    resources = ["*"]
  }

  statement {
    actions = ["cloudwatch:PutMetricData"]

    resources = ["*"]
  }

  statement {
    actions = ["kms:Describe*"]

    resources = ["*"]
  }
}
