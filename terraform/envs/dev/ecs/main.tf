locals {
  s3_bucket_aegea_ecs_execute = "aegea-ecs-execute-${var.env}-${var.aws_accounts.idseq-dev}"
  # Off-hours window (UTC) for scheduled scale-to-zero — see ecs_scale_to_zero.tf (CZID-292 / #248).
  off_hour_utc = 3  # ~19:00 US-Pacific: scale cluster to 0
  on_hour_utc  = 13 # ~05:00 US-Pacific: scale cluster back to baseline
}

module "ecs-cluster" {
  # Dev runs on EKS/Argo. The ECS cluster and its ASG were torn down at the migration, but terraform
  # still declared them -- so a refreshed plan wanted to RE-CREATE the cluster plus an ASG of real EC2
  # instances, duplicating workloads that already run as k8s pods and costing money.
  #
  # This gates ONLY the compute plane. The security group, log group, instance profile and IAM policy
  # the module also owns are deliberately NOT gated: dev/redis reads the SG, and dev/batch keys
  # random_id.batch on it -- if that SG id changed, the AWS Batch compute environment would be
  # REPLACED. See platform-overhaul #687.
  create_compute = false

  source = "../../../modules/ecs-cluster-v2.4.0"

  region  = var.region
  project = var.project
  owner   = var.owner
  env     = var.env
  # ami     = "ami-0010b929226fe8eba" //TODO - pull dynamically - aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended --region us-east-1

  min_servers                        = 2 # 4
  max_servers                        = 4 # 20
  cluster_asg_rolling_interval_hours = 0 # 24

  # off_hour_utc = local.off_hour_utc
  # on_hour_utc  = local.on_hour_utc

  instance_type       = "m5.2xlarge"
  vpc_id              = data.terraform_remote_state.cloud-env.outputs.vpc_id
  ssh_key_name        = null # "idseq-${var.env}"
  subnets             = data.terraform_remote_state.cloud-env.outputs.private_subnets
  allowed_cidr_blocks = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  # ssh_users           = data.terraform_remote_state.global.outputs.ssh_users
  docker_storage_size = "214"
}

# CZID-63: customer-managed KMS key encrypting the ECS log group. The key policy
# grants CloudWatch Logs use of the key, scoped to this log group's ARN via the
# encryption-context condition. Root gets the standard lockout-prevention grant.
data "aws_iam_policy_document" "ecs_logs_kms" {
  #checkov:skip=CKV_AWS_111:key policy resource is implicitly the key itself; cannot scope
  #checkov:skip=CKV_AWS_356:key policy resource is implicitly the key itself; cannot scope
  #checkov:skip=CKV_AWS_109:root kms:* is the required lockout-prevention grant for a CMK
  statement {
    sid       = "RootAdmin"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid       = "CloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:ecs-logs-${var.env}"]
    }
  }
}

resource "aws_kms_key" "ecs_logs" {
  description             = "ecs-logs-${var.env} CloudWatch log group encryption (CZID-63)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.ecs_logs_kms.json
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "ecs-logs-${var.env}"
  retention_in_days = 365                      # >= 1yr (CKV_AWS_338); ECS task logs
  kms_key_id        = aws_kms_key.ecs_logs.arn # CMK-encrypted (CKV_AWS_158)
}

# The ASG scaling policies and the ECS memory-reservation alarms that lived here were removed: they
# only ever scaled the dev ECS AutoScalingGroup, which was torn down at the EKS migration. They do not
# exist in AWS (the refreshed plan wanted to CREATE them), so dropping them from config is a no-op, not
# a destroy. The intent -- scale down when idle -- moves to EKS/Karpenter (#688).

resource "aws_ecs_cluster" "idseq-fargate-tasks" {
  name = "idseq-fargate-tasks-development"
}

resource "aws_s3_bucket" "aegea-ecs-execute" {
  bucket        = local.s3_bucket_aegea_ecs_execute
  force_destroy = contains(["dev", "sandbox"], var.env)

  tags = {
    terraform = "true"
  }
}

# Inline `acl` and `lifecycle_rule` were deprecated in AWS provider v4 and moved
# to dedicated `aws_s3_bucket_*` resources (#475). Apply-safe: no bucket recreation.
#
# The aws_s3_bucket_acl "private" resource was REMOVED: S3 disables ACLs by default
# (BucketOwnerEnforced) since April 2023, so PutBucketAcl now fails outright with
# InvalidArgument and took the whole ecs stack down. A "private" canned ACL was always a
# no-op here anyway -- the bucket is private by default and access is governed by IAM.

resource "aws_s3_bucket_lifecycle_configuration" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id

  rule {
    id     = "ExpireRule"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration {
      days = 30
    }
  }
}

resource "aws_security_group" "aegea-ecs" {
  name        = "aegea.ecs"
  description = "undocumented but required Security Group needed by ECS to execute Download tasks"
  # Bind to the Terraform-managed cloud-env VPC (matches staging/prod). This previously
  # pointed at data.aws_vpc.default (the account default VPC), which (a) placed the
  # bulk-download Fargate SG in the wrong VPC — bulk downloads couldn't reach cloud-env
  # services — and (b) forced an account default VPC to exist for `apply` to plan at all.
  vpc_id = data.terraform_remote_state.cloud-env.outputs.vpc_id
  tags = {
    Name = "aegea.ecs"
  }
}

resource "aws_security_group_rule" "aegea-ecs-egress-443-all-tcp" {
  description       = "Allow Fargate ECS to communicate with ECR"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.aegea-ecs.id
  cidr_blocks       = ["0.0.0.0/0"]
}

module "web-params" {
  source  = "../../../modules/aws-ssm-params-writer-v0.104.2" # cztack v0.104.2
  project = var.project
  env     = var.env
  service = "web"
  owner   = var.owner

  parameters = {
    S3_AEGEA_ECS_EXECUTE_BUCKET = local.s3_bucket_aegea_ecs_execute
    # OpenTelemetry (#426/#608): the OTLP HTTP endpoint of the in-cluster OTel collector on eks-v2.
    # Chamber surfaces this to every service (web + Resque/Shoryuken workers all load idseq-<env>-web);
    # the app's initializer is inert until this is present. The old ECS ADOT collector
    # (collector.<env>.otel.internal) was RETIRED when dev moved to eks-v2 -- this now points at the
    # Kubernetes OTel Collector service (monitoring ns), which is what the live app already uses and
    # what makes traces/span-metrics flow to Tempo/Prometheus. Same across eks envs (same ns/release).
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318"
  }
}

resource "aws_s3_bucket_versioning" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "aegea-ecs-execute" {
  bucket                  = aws_s3_bucket.aegea-ecs-execute.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "aegea-ecs-execute" {
  bucket = aws_s3_bucket.aegea-ecs-execute.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# --- S3 server access logging (CZID-343) ---
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_145:S3 access-log delivery is unsupported with the aws/s3 managed KMS key; AES256 is the supported at-rest option for log destinations
  #checkov:skip=CKV_AWS_18:a log-destination bucket does not log to itself (would recurse)
  #checkov:skip=CKV_AWS_144:cross-region replication is not warranted for short-lived access logs
  #checkov:skip=CKV2_AWS_62:no event-notification consumer for access logs
  bucket = "ecs-s3-access-logs-${var.env}-${data.aws_caller_identity.current.account_id}"
  tags   = { terraform = true }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "S3ServerAccessLogsPolicy"
      Effect    = "Allow"
      Principal = { Service = "logging.s3.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.access_logs.arn}/*"
      Condition = {
        ArnLike      = { "aws:SourceArn" = [aws_s3_bucket.aegea-ecs-execute.arn] }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_s3_bucket_logging" "aegea-ecs-execute" {
  bucket        = aws_s3_bucket.aegea-ecs-execute.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "aegea-ecs-execute/"
}
