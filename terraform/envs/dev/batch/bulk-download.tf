# Bulk-download tar job on AWS Batch -- Phase 1 of migrating bulk downloads off the legacy
# aegea -> ECS-Fargate launcher onto EKS/Batch (Forgejo #846 / SMP-1477; Sentry DEV-RAILS-PROJECT-25).
#
# The s3_tar_writer container (idseq-s3-tar-writer ECR image) is launcher-agnostic -- aegea only
# ever *ran* it. Here we register it as a Batch job definition that the web app submits to the
# EXISTING idseq-<env>-lomem queue (see main.tf), overriding the container `command` with the
# real s3_tar_writer args (--src-urls / --tar-names / --dest-url / --success-url / ...) at
# SubmitJob time. Retires the aegea cluster/bucket/CreateBucket dependency entirely.
#
# Apply (reviewer-gated): targeted-apply on component `batch` for
#   aws_iam_role.bulk_download_job aws_iam_role_policy.bulk_download_job
#   aws_cloudwatch_log_group.bulk_download aws_batch_job_definition.bulk_download

data "aws_ecr_repository" "s3_tar_writer" {
  name = "idseq-s3-tar-writer"
}

# The task (job) role the tar container assumes: read sample results + references, write the
# archive back to the samples bucket. Least-privilege; independent of the Batch instance role.
data "aws_iam_policy_document" "bulk_download_job_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bulk_download_job" {
  name               = "seqtoid-web-${var.env}-bulk-download-job"
  assume_role_policy = data.aws_iam_policy_document.bulk_download_job_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "bulk_download_job" {
  statement {
    sid     = "ListSourceBuckets"
    actions = ["s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}",
      "arn:aws:s3:::${var.s3_bucket_public_references}",
    ]
  }
  statement {
    sid     = "ReadSources"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
      "arn:aws:s3:::${var.s3_bucket_samples_v1}/*",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
    ]
  }
  statement {
    # Downloads are written to SAMPLES_BUCKET_NAME_V1 (the app's download_bucket_name =
    # s3_bucket_samples_v1), NOT the plain samples bucket. Verified on dev:
    # SAMPLES_BUCKET_NAME_V1=czi-infectious-disease-dev-samples-<acct>.
    sid       = "WriteArchive"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_samples_v1}/*"]
  }
}

resource "aws_iam_role_policy" "bulk_download_job" {
  name   = "seqtoid-web-${var.env}-bulk-download-job"
  role   = aws_iam_role.bulk_download_job.id
  policy = data.aws_iam_policy_document.bulk_download_job.json
}

resource "aws_cloudwatch_log_group" "bulk_download" {
  # checkov:skip=CKV_AWS_158:Dev bulk-download operational logs (tar progress/errors) carry no PII or
  # secrets; unencrypted is consistent with the other dev log groups. KMS CMK is a staging/prod concern.
  name              = "/seqtoid/${var.env}/bulk-download"
  retention_in_days = 365 # CKV_AWS_338 (>= 1y)
  tags              = var.tags
}

resource "aws_batch_job_definition" "bulk_download" {
  name                  = "seqtoid-web-${var.env}-bulk-download"
  type                  = "container"
  platform_capabilities = ["EC2"]

  container_properties = jsonencode({
    image      = "${data.aws_ecr_repository.s3_tar_writer.repository_url}:latest"
    jobRoleArn = aws_iam_role.bulk_download_job.arn
    # Placeholder only -- the app overrides `command` at SubmitJob with the s3_tar_writer args.
    command = ["python", "s3_tar_writer.py", "--help"]
    resourceRequirements = [
      { type = "VCPU", value = "4" },
      { type = "MEMORY", value = "8192" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.bulk_download.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "bulk-download"
      }
    }
  })

  retry_strategy {
    attempts = 2
  }
  timeout {
    attempt_duration_seconds = 10800 # 3h cap
  }
  tags = var.tags
}

output "bulk_download_job_definition_arn" {
  value = aws_batch_job_definition.bulk_download.arn
}

output "bulk_download_job_role_arn" {
  value = aws_iam_role.bulk_download_job.arn
}
