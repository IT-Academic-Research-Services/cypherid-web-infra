locals {
  name = "${var.project}-${var.env}-${var.service}"

  tags = {
    managedBy = "terraform"
    Name      = "${var.project}-${var.env}-${var.service}"
    project   = var.project
    env       = var.env
    service   = var.service
    owner     = var.owner
    terraform = "true"
  }

  alb_arn            = element(concat(aws_alb.service-access-logs.*.arn, aws_alb.service.*.arn), 0)
  alb_dns_name       = element(concat(aws_alb.service-access-logs.*.dns_name, aws_alb.service.*.dns_name), 0)
  alb_zone_id        = element(concat(aws_alb.service-access-logs.*.zone_id, aws_alb.service.*.zone_id), 0)
  access_logs_prefix = var.access_logs_bucket == "" ? "" : local.name
}

resource "aws_alb" "service" {
  count = var.access_logs_bucket != "" ? 0 : 1

  name            = local.name
  internal        = var.internal
  security_groups = concat(var.security_group_ids, compact(tolist([module.sg.security_group_id])))
  subnets         = var.subnets
  idle_timeout    = var.idle_timeout

  tags = local.tags
}

resource "aws_alb" "service-access-logs" {
  count = var.access_logs_bucket != "" ? 1 : 0

  name            = local.name
  internal        = var.internal
  security_groups = concat(var.security_group_ids, compact(tolist([module.sg.security_group_id])))
  subnets         = var.subnets
  idle_timeout    = var.idle_timeout

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = local.access_logs_prefix
    enabled = true
  }

  tags = local.tags
}

resource "aws_alb_listener" "http" {
  count = var.disable_http_redirect ? 1 : 0

  load_balancer_arn = local.alb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = var.target_group_arn
    type             = "forward"
  }
}

resource "aws_alb_listener" "http-redirect" {
  count = var.disable_http_redirect ? 0 : 1

  load_balancer_arn = local.alb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = local.alb_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = var.target_group_arn
    type             = "forward"
  }
}

# Default security group if none is provided.
module "sg" {
  create  = var.create_security_group
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.3.0"

  name        = "${local.name}-alb"
  description = "Security group for ${var.internal ? "internal" : "internet facing"} ALB"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress_cidr_blocks = var.ingress_cidrs
  egress_cidr_blocks  = var.egress_cidrs
  ingress_rules       = ["https-443-tcp", "http-80-tcp"]
  egress_rules        = ["all-all"]
}
