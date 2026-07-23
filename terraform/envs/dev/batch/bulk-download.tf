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
  # Transitional: the ECS-task trust is for the Batch launcher (Phase 2, being retired).
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
  # IRSA: the tar Job's ServiceAccount (seqtoid-dev/seqtoid-web-bulk-download on eks-v2) assumes
  # this role via the cluster OIDC provider -- the K8s-Job launcher (latency follow-up). dev-scoped
  # OIDC ARN; mirror per env when staging/prod land.
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::491013321714:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/8BA8D002F1153454A70ADEE48679D311"]
    }
    condition {
      test     = "StringEquals"
      variable = "oidc.eks.us-west-2.amazonaws.com/id/8BA8D002F1153454A70ADEE48679D311:sub"
      values   = ["system:serviceaccount:seqtoid-dev:seqtoid-web-bulk-download"]
    }
    condition {
      test     = "StringEquals"
      variable = "oidc.eks.us-west-2.amazonaws.com/id/8BA8D002F1153454A70ADEE48679D311:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bulk_download_job" {
  name               = "seqtoid-web-${var.env}-bulk-download-job"
  assume_role_policy = data.aws_iam_policy_document.bulk_download_job_trust.json
  tags               = var.tags
}

# The AWS-managed aws/s3 key that SSE-KMS-encrypts the sample buckets by default (dev buckets use
# the managed key, not a customer CMK -- verified via get-bucket-encryption). Referenced by alias so
# no key UUID is hardcoded.
data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
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
  statement {
    # The sample objects (and the archive written back) are SSE-KMS encrypted with the AWS-managed
    # aws/s3 key, so reading a source and writing the tar need KMS, not just S3. Without this the
    # presigned GET returns a 403 (KMS AccessDenied); s3_tar_writer does not raise on 403 and streams
    # the short error body, failing with "unexpected end of data". kms:Decrypt reads the SSE-KMS
    # sources; kms:GenerateDataKey encrypts the archive on PutObject. The legacy aegea/ECS task role
    # carried this grant; the aegea -> Batch/EKS migration dropped it (#846 / SMP-1477). Scoped via
    # kms:ViaService so the role can only use the key through S3, never call KMS directly.
    sid       = "SseKmsViaS3"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [data.aws_kms_alias.s3.target_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }
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
