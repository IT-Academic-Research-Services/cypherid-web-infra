module "czid_web_private_gh_actions_executor" {
  source = "github.com/chanzuckerberg/cztack//aws-iam-role-github-action?ref=v0.104.2"

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-executor"
  }
  authorized_github_repos = {
    # chanzuckerberg : ["czid-web-private", "idseq"]
    "IT-Academic-Research-Services" : [
      "cypherid-web-infra",
      "cypherid-workflow-infra",
      "seqtoid-graphql-federation-server",
      "seqtoid-web",
      "seqtoid-workflows"
    ]
  }
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  client_id_list  = ["sts.amazonaws.com"]
}

# TODO: Adds near-superuser power to the CI/CD process
resource "aws_iam_role_policy_attachment" "czid_ci_cd_poweruser" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
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

resource "aws_iam_role_policy_attachment" "czid_ci_cd_tagging" {
  role       = module.czid_web_private_gh_actions_executor.role.name
  policy_arn = "arn:aws:iam::aws:policy/ResourceGroupsTaggingAPITagUntagSupportedResources"
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
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::czid-public-references",
      "arn:aws:s3:::czid-public-references/*",
      "arn:aws:s3:::aegea-batch-jobs-${var.account_id}",
      "arn:aws:s3:::aegea-batch-jobs-${var.account_id}/*",
      "arn:aws:s3:::idseq-${var.env}-*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
    ]
  }

  statement {
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:PutObject*"
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}",   # TODO: Is this necessary?
      "arn:aws:s3:::${var.s3_bucket_samples}/*", # TODO: Is this necessary?
      "arn:aws:s3:::${var.s3_bucket_workflows}",
      "arn:aws:s3:::${var.s3_bucket_workflows}/*",
      "arn:aws:s3:::tfstate-${var.account_id}",
      "arn:aws:s3:::tfstate-${var.account_id}/*",
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
      "arn:aws:lambda:*:${var.account_id}:function:idseq-*",
      "arn:aws:lambda:*:${var.account_id}:function:cloudwatch-alerting-*"
    ]
  }
  statement {
    actions = ["secretsmanager:*"]

    resources = [
      "arn:aws:secretsmanager:*:${var.account_id}:secret:idseq/*"
    ]
  }
  statement {
    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${var.account_id}:role/idseq-${var.env}-*",
      "arn:aws:iam::${var.account_id}:role/idseq-swipe-${var.env}-*",
      "arn:aws:iam::${var.account_id}:role/idseq-web-*"
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
      "arn:aws:sqs:*:${var.account_id}:idseq-${var.env}-*",
      "arn:aws:sqs:*:${var.account_id}:idseq-swipe-*"
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
      "arn:aws:ssm:*:${var.account_id}:parameter/idseq-${var.env}-*"
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
      "arn:aws:ecs:*:${var.account_id}:service/${var.env}/*",
      "arn:aws:ecs:*:${var.account_id}:service/idseq-${var.env}-ecs/*",
      "arn:aws:ecs:*:${var.account_id}:task-definition/idseq-${var.env}-web:*",
      "arn:aws:ecs:*:${var.account_id}:task/idseq-${var.env}-ecs/*",
      "arn:aws:ecs:*:${var.account_id}:task/${var.env}/*",
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
