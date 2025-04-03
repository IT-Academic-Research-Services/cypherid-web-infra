locals {
  # If the user provides a task definition, we assume that Terraform will
  # manage the lifecycle of the container definition; any external changes
  # are reset on the next Terraform run. If the task definition is omitted,
  # we assume the user will manage the container definition external to
  # Terraform (e.g. using czecs), and thus we wiil ignore any changes to the
  # definition, and use a stub definition in its place.
  tf_managed_task = var.task_definition != ""

  container_name = var.container_name == "" ? local.name : var.container_name

  # This could be done by putting this directly in the aws_ecs_service clauses below
  # depending on it is a Fargate service or not, but having this single task_definition
  # future proofs us against Terraform 0.12, where we intend to merge all the service
  # definitions into a single resource when Terraform has support for optional block syntax.
  task_definition = join(":",
    tolist([
      element(concat(aws_ecs_task_definition.fargate_job.*.family, aws_ecs_task_definition.job.*.family), 0),
      element(concat(aws_ecs_task_definition.fargate_job.*.revision, aws_ecs_task_definition.job.*.revision), 0),
    ])
  )
}

module "alb-sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "4.3.0"
  create      = var.use_fargate
  name        = "${local.name}-alb"
  description = "Security group for ${var.internal_lb ? "internal" : "internet facing"} ALB"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress_rules       = ["https-443-tcp", "http-80-tcp"]
  ingress_cidr_blocks = var.lb_ingress_cidrs

  number_of_computed_egress_with_source_security_group_id = 1

  computed_egress_with_source_security_group_id = [
    {
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      description              = "Container port"
      source_security_group_id = module.container-sg.security_group_id
    },
  ]
}

module "container-sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "4.3.0"
  create      = var.use_fargate
  name        = local.name
  description = "ECS ingress port"
  vpc_id      = var.vpc_id
  tags        = local.tags

  number_of_computed_ingress_with_source_security_group_id = 1

  computed_ingress_with_source_security_group_id = [
    {
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      description              = "Container port"
      source_security_group_id = module.alb-sg.security_group_id
    },
  ]

  # TODO(mbarrien): Make this configurable to either be passsed in or to be able to be narrowed.
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

# Only one of the following is active at a time, depending on whether or not a task definition was provided and on use_fargate flag
resource "aws_ecs_service" "job" {
  name    = local.name
  cluster = var.cluster_id
  count   = !var.use_fargate && local.tf_managed_task ? 1 : 0

  task_definition                   = local.task_definition
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  load_balancer {
    target_group_arn = aws_alb_target_group.service.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = ["module.alb"]
}

resource "aws_ecs_service" "unmanaged-job" {
  name    = local.name
  cluster = var.cluster_id
  count   = !var.use_fargate && !local.tf_managed_task ? 1 : 0

  task_definition                   = local.task_definition
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  load_balancer {
    target_group_arn = aws_alb_target_group.service.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = ["module.alb"]
}

resource "aws_service_discovery_private_dns_namespace" "discovery" {
  count       = var.with_service_discovery ? 1 : 0
  name        = "${local.name}.terraform.local"
  description = "Namespace for service discovery for ${local.name}"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "discovery" {
  count       = var.with_service_discovery ? 1 : 0
  name        = local.name
  description = "Service discovery for ${local.name}"

  health_check_custom_config {
    failure_threshold = 1
  }

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.discovery.*.id[count.index]

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_service" "fargate-job" {
  name        = local.name
  cluster     = var.cluster_id
  count       = var.use_fargate && !var.with_service_discovery && local.tf_managed_task ? 1 : 0
  launch_type = "FARGATE"

  task_definition                   = local.task_definition
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets         = var.fargate_task_subnets
    security_groups = [module.container-sg.security_group_id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.service.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = ["module.alb"]
}

resource "aws_ecs_service" "unmanaged-fargate-job" {
  name        = local.name
  cluster     = var.cluster_id
  count       = var.use_fargate && !var.with_service_discovery && !local.tf_managed_task ? 1 : 0
  launch_type = "FARGATE"

  task_definition                   = local.task_definition
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets         = var.fargate_task_subnets
    security_groups = [module.container-sg.security_group_id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.service.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = ["module.alb"]
}

resource "aws_ecs_service" "fargate-discovery-job" {
  name        = local.name
  cluster     = var.cluster_id
  count       = var.use_fargate && var.with_service_discovery && local.tf_managed_task ? 1 : 0
  launch_type = "FARGATE"

  task_definition                   = local.task_definition
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets         = var.fargate_task_subnets
    security_groups = [module.container-sg.security_group_id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.service.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  service_registries {
    registry_arn = element(aws_service_discovery_service.discovery.*.arn, 0)
  }

  depends_on = ["module.alb"]
}

resource "aws_ecs_service" "unmanaged-fargate-discovery-job" {
  name        = local.name
  cluster     = var.cluster_id
  count       = var.use_fargate && var.with_service_discovery && !local.tf_managed_task ? 1 : 0
  launch_type = "FARGATE"

  task_definition                   = local.task_definition
  desired_count                     = var.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets         = var.fargate_task_subnets
    security_groups = [module.container-sg.security_group_id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.service.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  service_registries {
    registry_arn = element(aws_service_discovery_service.discovery.*.arn, 0)
  }

  depends_on = ["module.alb"]
}

# Default container definition if no task_definition is provided.
# Defaults to a minimal hello-world implementation; should be updated separately from
# Terraform, e.g. using ecs deploy or czecs

data "template_file" "task" {
  count = var.use_fargate ? 0 : 1

  template = <<TEMPLATE
[
  {
    "name": "${local.container_name}",
    "image": "library/busybox:1.29",
    "command": ["sh", "-c", "while true; do { echo -e 'HTTP/1.1 200 OK\r\n\nRunning stub server'; date; } | nc -l -p ${var.container_port}; done"],
    "memoryReservation": 4,
    "portMappings": [
      {
        "containerPort": ${var.container_port},
        "hostPort": 0
      }
    ]
  }
]
TEMPLATE
}

data "template_file" "fargate_task" {
  count = var.use_fargate ? 1 : 0

  template = <<TEMPLATE
[
  {
    "name": "${local.container_name}",
    "image": "library/busybox:1.29",
    "command": ["sh", "-c", "while true; do { echo -e 'HTTP/1.1 200 OK\r\n\nRunning stub server'; date; } | nc -l -p ${var.container_port}; done"],
    "portMappings": [
      {
        "containerPort": ${var.container_port},
        "hostPort":  ${var.container_port}
      }
    ]
  }
]
TEMPLATE
}

data "aws_iam_policy_document" "execution_role" {
  count = var.use_fargate ? 1 : 0

  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "task_execution_role" {
  count              = var.use_fargate ? 1 : 0
  name               = "${local.name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.execution_role.*.json[count.index]
}

# TODO(mbarrien): We can probably narrow this down to allowing access to only
# the specific ECR arn if applicable, and the specific cloudwatch log group.
# Either pass both identifiers in, or pass the entire role ARN as an argument
resource "aws_iam_role_policy_attachment" "task_execution_role" {
  count      = var.use_fargate ? 1 : 0
  role       = aws_iam_role.task_execution_role.*.name[count.index]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "registry_secretsmanager" {
  count = var.use_fargate && var.registry_secretsmanager_arn != "" ? 1 : 0

  statement {
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
    ]

    resources = [var.registry_secretsmanager_arn]
  }
}

resource "aws_iam_role_policy" "task_execution_role_secretsmanager" {
  count  = var.use_fargate && var.registry_secretsmanager_arn != "" ? 1 : 0
  role   = aws_iam_role.task_execution_role.*.name[count.index]
  policy = data.aws_iam_policy_document.registry_secretsmanager.*.json[count.index]
}

resource "aws_ecs_task_definition" "job" {
  count                 = var.use_fargate ? 0 : 1
  family                = local.name
  container_definitions = local.tf_managed_task ? var.task_definition : data.template_file.task.*.rendered[count.index]
  task_role_arn         = var.task_role_arn
}

resource "aws_ecs_task_definition" "fargate_job" {
  count                    = var.use_fargate ? 1 : 0
  family                   = local.name
  container_definitions    = local.tf_managed_task ? var.task_definition : data.template_file.fargate_task.*.rendered[count.index]
  task_role_arn            = var.task_role_arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.task_execution_role.*.arn[count.index]
}
