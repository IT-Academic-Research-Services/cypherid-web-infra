locals {
  s3_bucket_workflows         = "seqtoid-workflows-${var.env}-${var.aws_accounts.idseq-dev}"
  s3_bucket_aegea_ecs_execute = data.terraform_remote_state.ecs.outputs.s3_bucket_aegea_ecs_execute

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
      "arn:aws:s3:::${local.s3_bucket_aegea_ecs_execute}",
      "arn:aws:s3:::${local.s3_bucket_workflows}",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectTagging",
    ]

    resources = [
      "arn:aws:s3:::seqtoid-sandbox/*",
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
      "arn:aws:s3:::${local.s3_bucket_aegea_ecs_execute}/*",
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
      "arn:aws:s3:::${local.s3_bucket_aegea_ecs_execute}/*",
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
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}/*",
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
      type = "AWS"
      # The web app assumes this role to mint scoped S3 upload creds for the browser
      # (get_upload_credentials -> CLI_UPLOAD_ROLE_ARN). BOTH the ECS task role AND the
      # EKS/IRSA pod role must be trusted so uploads work on either runtime during the
      # ECS->EKS strangler (#489). Drop idseq-web once ECS dev is decommissioned (Phase 5).
      #
      # seqtoid_web_preview is here because per-PR sandbox pods run as THAT role, not
      # seqtoid_web_eks -- so every sandbox upload died server-side, before S3 was ever
      # reached, with a 500 from /samples/N/upload_credentials.json:
      #   Aws::STS::Errors::AccessDenied (User: .../seqtoid-web-preview is not authorized to
      #   perform: sts:AssumeRole on resource: .../idseq-upload-dev)
      # This is why sandbox uploads NEVER worked. Granting the preview bucket on the role's
      # policy (#29) was necessary but not sufficient: a session policy intersects with the
      # role's permissions, and none of that matters if the caller cannot assume the role at
      # all. Trust and permissions are separate locks and the sandbox failed both.
      #
      # This does NOT widen what a sandbox can write: the session policy the app builds is
      # scoped to $SAMPLES_BUCKET_NAME/<file_path> (the sandbox's own bucket), and the role's
      # own policy is scoped to */samples/*. A sandbox still cannot touch dev's samples.
      identifiers = [
        aws_iam_role.idseq-web.arn,
        aws_iam_role.seqtoid_web_eks.arn,
        aws_iam_role.seqtoid_web_preview.arn,
      ]
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
      # Per-PR preview sandboxes upload to their own bucket (#697). The app mints these creds by
      # assuming THIS role with a session policy scoped to
      # `arn:aws:s3:::$SAMPLES_BUCKET_NAME/<file_path>` (samples_helper.rb get_upload_credentials).
      # A session policy INTERSECTS with this identity policy, so a sandbox's request for
      # seqtoid-preview-samples-*/samples/* against a role that only allows idseq-samples-dev
      # intersected to NOTHING and every sandbox upload failed with "All uploads failed".
      #
      # This is why sandbox uploads NEVER worked -- including against the old `seqtoid-sandbox`
      # bucket, which this role was never granted either. (Which also means the browser upload path
      # could never write into that 4.8 TB research bucket: it had no permission. Only the preview
      # IRSA role did, server-side, and that grant is now withdrawn.)
      #
      # Same /samples/* prefix scoping as dev: a sandbox can only ever write under samples/.
      "${aws_s3_bucket.preview_samples.arn}/samples/*",
    ]
  }
}

resource "aws_iam_role_policy" "idseq-upload" {
  name   = "idseq-upload-${var.env}"
  role   = aws_iam_role.idseq-upload.id
  policy = data.aws_iam_policy_document.idseq-upload.json
}

module "parameters-policy" {
  source = "../../../modules/aws-params-reader-policy-v0.104.2" # cztack v0.104.2

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
  source  = "../../../modules/aws-ssm-params-writer-v0.104.2" # cztack v0.104.2
  project = var.project
  env     = var.env
  service = var.component
  owner   = var.owner

  parameters = {
    REDISCLOUD_URL                = "rediss://${data.terraform_remote_state.redis.outputs.primary_endpoint_address}:6379"
    ALIGNMENT_CONFIG_DEFAULT_NAME = var.alignment_index_date
    CLOUDFRONT_ENDPOINT           = local.assets_fqdn
    CZID_CLOUDFRONT_ENDPOINT      = local.assets_fqdn
    S3_DATABASE_BUCKET            = var.s3_bucket_public_references
    CLI_UPLOAD_ROLE_ARN           = aws_iam_role.idseq-upload.arn
    SECRET_KEY_BASE               = random_string.secret_key_base.result
    SERVER_DOMAIN                 = "https://${data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn}"
    AUTO_ACCOUNT_CREATION_V1      = 1
    S3_WORKFLOWS_BUCKET           = local.s3_bucket_workflows
    LAMBDA_ENV                    = var.env # TODO: Only necessary for dev, as it defaults to Rails.env ('development') in the code
  }
}

module "staging" {
  source = "../../../modules/aws-acm-certificate-v0.104.2" # cztack v0.104.2

  cert_domain_name    = local.env_fqdn
  aws_route53_zone_id = local.zone_id
  tags                = var.tags # TODO: var.tags is deprecated

  cert_subject_alternative_names = {
    (local.www_env_fqdn) = local.zone_id
  }
}

module "staging_east" {
  source = "../../../modules/aws-acm-certificate-v0.104.2" # cztack v0.104.2

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

  service        = "web"
  project        = var.project
  owner          = var.owner
  container_port = 3000
  container_name = "rails"
  env            = var.env
  vpc_id         = data.terraform_remote_state.cloud-env.outputs.vpc_id
  cluster_id     = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn  = aws_iam_role.idseq-web.arn
  # Dev runs on EKS/Argo (the app + resque are k8s pods) and the ECS cluster was torn down at
  # the migration, so creating an ECS service here fails with ClusterNotFoundException. Keep the
  # ALB / target group / task definition (still present and still referenced) but do NOT create
  # the service. staging/prod are unaffected -- the module defaults create_service = true.
  # See platform-overhaul #687.
  create_service = false
  # The edge is a Kubernetes Ingress now: the AWS load-balancer controller owns the k8s-seqtoidd-*
  # ALB and external-dns owns dev.seqtoid.org. This module still declared the same records pointing
  # at the ECS ALB, so a refreshed plan wanted to repoint the live hostname at an ALB with ZERO
  # healthy targets -- i.e. take dev offline. Terraform must stop claiming records it no longer owns.
  # staging/prod still front on ECS and keep their records (the module defaults to true). See #693.
  manage_dns_records                = false
  desired_count                     = 1
  lb_subnets                        = data.terraform_remote_state.cloud-env.outputs.public_subnets
  route53_zone_id                   = local.zone_id
  subdomain                         = ""
  health_check_path                 = "/health_check"
  health_check_grace_period_seconds = 600
  acm_certificate_arn               = module.staging.arn
  lb_egress_cidrs                   = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  access_logs_bucket                = data.terraform_remote_state.elb-access-logs.outputs.bucket_name

  # The AWS and module default is 60s. We decided to increase it after observing
  # multiple endpoints exceeding that in production under normal loads, including
  # bulk_upload_with_metadata and report_csv.
  lb_idle_timeout_seconds = 300
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# www.dev.seqtoid.org was declared here, aliased to the ECS ALB. external-dns now owns it (it points
# at the k8s Ingress ALB), so terraform must let go -- but it must NOT delete the record on the way
# out, which is exactly what removing the resource block alone would do (destroy = the hostname stops
# resolving). `removed` with destroy = false drops it from state and leaves the live record standing.
#
# Keep this block. Deleting it does nothing once state is clean, but while any state still carries the
# resource, removing this block silently re-arms the destroy.
removed {
  from = aws_route53_record.www

  lifecycle {
    destroy = false
  }
}

resource "aws_ecr_repository" "web-repository" {
  #checkov:skip=CKV_AWS_51:image tag immutability is intentionally gated behind var.ecr_immutable_tags (default MUTABLE) — flipping it unconditionally broke the latest-tag dual-push deploy (see #59/PR#110); re-enable once the deploy uses immutable sha/SemVer tags.
  name = "idseq-web"
  # CZID-59: IMMUTABLE tags (CKV_AWS_51). This is an in-place update on an existing
  # repo (PutImageTagMutability), NOT a replacement.
  image_tag_mutability = var.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = contains(["dev", "sandbox"], var.env)

  image_scanning_configuration {
    scan_on_push = true
  }

  # CZID-59: customer-managed KMS encryption of image layers (CKV_AWS_136), gated on
  # var.manage_ecr_kms_cmk. encryption_configuration is IMMUTABLE — enabling it on an
  # existing repo forces DESTROY+RECREATE, so it is emitted ONLY on greenfield envs
  # (see ecr_hardening.tf). When the var is false the block is absent and the repo
  # keeps the AWS-owned key with no change.
  dynamic "encryption_configuration" {
    for_each = var.manage_ecr_kms_cmk ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = local.ecr_kms_key_arn
    }
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
