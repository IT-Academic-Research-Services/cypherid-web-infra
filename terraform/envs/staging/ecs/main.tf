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
  bucket = var.s3_bucket_aegea_ecs_execute
  acl    = "private"

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
