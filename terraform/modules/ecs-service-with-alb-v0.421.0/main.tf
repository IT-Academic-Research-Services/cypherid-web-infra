# **_DEPRECATED: Use cztack/aws-ecs-service or cztack/aws-ecs-service-fargate instead._**

locals {
  name = "${var.project}-${var.env}-${var.service}"

  default_tags = {
    managedBy = "terraform"
    Name      = "${var.project}-${var.env}-${var.service}"
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
  }

  tags = merge(var.extra_tags, local.default_tags)
}
