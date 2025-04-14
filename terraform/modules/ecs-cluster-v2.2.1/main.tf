locals {
  name = var.ecs_cluster_name == "" ? "${var.project}-${var.env}-${var.service}" : var.ecs_cluster_name
  ami  = var.ami

  max_servers = max(var.max_servers, var.min_servers + 1)

  tags = {
    managedBy = "terraform"
    Name      = local.name
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
  }

  # If we are cycling instances, we pick a random in the first half of the hour
  #  at that time on the appointed hours we scale the cluster up by 1. We then
  #  scale it back down 15 minutes later.
  rolling_start_hour_offset = random_id.rand.dec % 30

  rolling_end_hour_offset = local.rolling_start_hour_offset + 15
}

resource "random_id" "rand" {
  byte_length = 1
}

resource "aws_ecs_cluster" "cluster" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  lifecycle {
    ignore_changes = [name]
  }

  tags = local.tags
}

# module "images" {
#   source = "../machine-images"
# }

module "logs" {
  source            = "github.com/chanzuckerberg/cztack//aws-cloudwatch-log-group?ref=v0.43.1"
  project           = var.project
  env               = var.env
  service           = var.service
  owner             = var.owner
  retention_in_days = var.log_retention_in_days
}

# module "orgwide-secrets" {
#   source    = "../aws-iam-policy-orgwide-secrets"
#   role_name = module.profile.role_name
# }

resource "aws_autoscaling_lifecycle_hook" "graceful_shutdown_asg_hook" {
  name                   = local.name
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = var.heartbeat_timeout
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  lifecycle {
    ignore_changes = [name]
  }
}

module "profile" {
  source      = "github.com/chanzuckerberg/cztack//aws-iam-instance-profile?ref=v0.60.0"
  name_prefix = "${local.name}-"
  iam_path    = var.iam_path
}

data "aws_iam_policy_document" "ecs-policy" {
  statement {
    actions = [
      "ecs:DeregisterContainerInstance",
      "ecs:RegisterContainerInstance",
      "ecs:Submit*",
    ]

    resources = [
      aws_ecs_cluster.cluster.arn,
    ]
  }
  statement {
    actions = [
      "ecs:Poll",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:UpdateContainerAgent",
    ]

    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.cluster.arn]
    }

  }
  statement {
    actions = [
      "ec2:DescribeTags",
      "ecs:DiscoverPollEndpoint",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }
  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs-policy" {
  name_prefix = "${local.name}-"
  description = "A terraform created policy for ECS"
  path        = var.iam_path
  policy      = data.aws_iam_policy_document.ecs-policy.json

  lifecycle {
    ignore_changes = [name]
  }
}

resource "aws_iam_role_policy_attachment" "attach-ecs" {
  role       = module.profile.role_name
  policy_arn = aws_iam_policy.ecs-policy.arn
}

module "attach-logs" {
  source    = "github.com/chanzuckerberg/cztack//aws-iam-policy-cwlogs?ref=v0.43.1"
  role_name = module.profile.role_name
  iam_path  = var.iam_path
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_launch_template" "ecs" {
  name_prefix   = local.name
  image_id      = local.ami
  instance_type = var.instance_type

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = module.profile.profile_name
  }

  vpc_security_group_ids = concat(tolist([module.sg.security_group_id]), var.security_group_ids)

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = var.docker_storage_size
      volume_type           = "gp3"
    }
  }

  user_data = module.user_data.script

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  update_default_version = true
}

resource "aws_autoscaling_group" "ecs" {
  name_prefix         = "${local.name}-"
  vpc_zone_identifier = var.subnets

  launch_template {
    name    = aws_launch_template.ecs.name
    version = "$Latest"
  }

  min_size             = var.min_servers
  max_size             = local.max_servers
  termination_policies = ["OldestInstance"]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  dynamic "tag" {
    for_each = merge(local.tags, var.ec2_extra_tags)

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }


  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 80
    }
    triggers = ["tag"]
  }
}

resource "aws_autoscaling_schedule" "ecs-up" {
  count                  = var.cluster_asg_rolling_interval_hours > 0 ? 1 : 0
  scheduled_action_name  = "${local.name}-up"
  desired_capacity       = var.min_servers + 1
  min_size               = var.min_servers
  max_size               = local.max_servers
  autoscaling_group_name = aws_autoscaling_group.ecs.name

  recurrence = "${local.rolling_start_hour_offset} */${var.cluster_asg_rolling_interval_hours} * * *"
}

resource "aws_autoscaling_schedule" "ecs-down" {
  count                  = var.cluster_asg_rolling_interval_hours > 0 ? 1 : 0
  scheduled_action_name  = "${local.name}-down"
  desired_capacity       = var.min_servers
  min_size               = var.min_servers
  max_size               = local.max_servers
  autoscaling_group_name = aws_autoscaling_group.ecs.name

  recurrence = "${local.rolling_end_hour_offset} */${var.cluster_asg_rolling_interval_hours} * * *"
}

//Scaling for lower environments to shut down off hours and resume on hours
resource "aws_autoscaling_schedule" "ecs-offhours" {
  count                  = var.cluster_asg_rolling_interval_hours == "0" ? 1 : 0
  scheduled_action_name  = "${local.name}-offhours"
  desired_capacity       = 0
  min_size               = 0
  max_size               = 0
  autoscaling_group_name = aws_autoscaling_group.ecs.name

  recurrence = "0 ${var.off_hour_utc} * * 2-6" # Monday - Friday at 8PM Pacific (Tue - Sat 3AM UTC)
}

resource "aws_autoscaling_schedule" "ecs-onhours" {
  count                  = var.cluster_asg_rolling_interval_hours == "0" ? 1 : 0
  scheduled_action_name  = "${local.name}-onhours"
  desired_capacity       = var.min_servers
  min_size               = var.min_servers
  max_size               = local.max_servers
  autoscaling_group_name = aws_autoscaling_group.ecs.name

  recurrence = "0 ${var.on_hour_utc} * * 1-5" # Monday - Friday at 6AM Pacific (Mon - Fri 3PM UTC)
}

module "sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "4.3.0"
  name        = local.name
  description = "Container Instance Allowed Ports"
  vpc_id      = data.aws_vpc.vpc.id
  tags        = local.tags

  ingress_cidr_blocks = var.allowed_cidr_blocks
  egress_cidr_blocks  = ["0.0.0.0/0"]
  ingress_rules       = ["all-tcp", "all-udp"]
  egress_rules        = ["all-all"]
}

data "template_file" "boothook" {
  template = file("${path.module}/templates/boothook.tpl")

  vars = {
    cluster_name = aws_ecs_cluster.cluster.name
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user_data.tpl")

  vars = {
    additional_user_data_script = var.additional_user_data_script
  }
}

module "user_data" {
  source          = "../instance-cloud-init-script-v0.484.6"
  user_script     = data.template_file.user_data.rendered
  user_boothook   = data.template_file.boothook.rendered
  //users           = var.ssh_users
  datadog_api_key = "" //var.datadog_api_key

  project = var.project
  env     = var.env
  service = var.service
  owner   = var.owner
}
