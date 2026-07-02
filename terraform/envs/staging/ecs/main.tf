locals {
  s3_bucket_aegea_ecs_execute = "aegea-ecs-execute-${var.env}-${var.aws_accounts.idseq-staging}"
}

module "ecs-cluster" {
  source = "../../../modules/ecs-cluster-v2.4.0"

  region  = var.region
  project = var.project
  owner   = var.owner
  env     = var.env
  # ami     = "ami-0010b929226fe8eba" //TODO - pull dynamically - aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2023/recommended --region us-east-1

  min_servers                        = 2 # TODO: was 8
  max_servers                        = 20
  cluster_asg_rolling_interval_hours = 24

  instance_type       = "m5.2xlarge"
  vpc_id              = data.terraform_remote_state.cloud-env.outputs.vpc_id
  ssh_key_name        = null # "idseq-${var.env}"
  subnets             = data.terraform_remote_state.cloud-env.outputs.private_subnets
  allowed_cidr_blocks = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  # ssh_users           = data.terraform_remote_state.global.outputs.ssh_users
  docker_storage_size = "214"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "ecs-logs-${var.env}"
}

resource "aws_autoscaling_policy" "scale-up" {
  name                   = "ecs-scale-up-${var.env}"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = module.ecs-cluster.asg_name
}

resource "aws_autoscaling_policy" "scale-down" {
  name                   = "ecs-scale-down-${var.env}"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = module.ecs-cluster.asg_name
}

resource "aws_cloudwatch_metric_alarm" "memory-res-high" {
  alarm_name  = "mem-res-high-ecs-${var.env}"
  namespace   = "AWS/ECS"
  metric_name = "MemoryReservation"

  dimensions = {
    ClusterName = module.ecs-cluster.cluster_name
  }

  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  alarm_actions = [
    aws_autoscaling_policy.scale-up.arn,
  ]
}

resource "aws_cloudwatch_metric_alarm" "memory-res-low" {
  alarm_name  = "mem-res-low-ecs-${var.env}"
  namespace   = "AWS/ECS"
  metric_name = "MemoryReservation"

  dimensions = {
    ClusterName = module.ecs-cluster.cluster_name
  }

  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  period              = "300"
  statistic           = "Average"
  threshold           = "60"

  alarm_actions = [
    aws_autoscaling_policy.scale-down.arn,
  ]
}

resource "aws_ecs_cluster" "idseq-fargate-tasks" {
  name = "idseq-fargate-tasks-${var.env}"
}

resource "aws_s3_bucket" "aegea-ecs-execute" {
  bucket        = local.s3_bucket_aegea_ecs_execute
  acl           = "private"
  force_destroy = contains(["dev", "sandbox"], var.env)

  lifecycle_rule {
    id      = "ExpireRule"
    enabled = true

    expiration {
      days = 30
    }
  }

  tags = {
    terraform = "true"
  }
}

resource "aws_security_group" "aegea-ecs" {
  name        = "aegea.ecs"
  description = "undocumented but required Security Group needed by ECS to execute Download tasks"
  vpc_id      = data.terraform_remote_state.cloud-env.outputs.vpc_id
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
