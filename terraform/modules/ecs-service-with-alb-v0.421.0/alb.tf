module "alb" {
  source = "../alb-http"

  project               = var.project
  env                   = var.env
  service               = var.service
  subnets               = var.lb_subnets
  vpc_id                = var.vpc_id
  ssl_policy            = var.ssl_policy
  egress_cidrs          = var.lb_egress_cidrs
  ingress_cidrs         = var.lb_ingress_cidrs
  idle_timeout          = var.lb_idle_timeout_seconds
  owner                 = var.owner
  certificate_arn       = var.acm_certificate_arn
  internal              = var.internal_lb
  disable_http_redirect = var.disable_http_redirect
  target_group_arn      = aws_alb_target_group.service.arn
  security_group_ids    = compact(tolist([module.alb-sg.security_group_id]))
  create_security_group = !var.use_fargate

  access_logs_bucket = var.access_logs_bucket
}

resource "aws_alb_target_group" "service" {
  name = local.name
  port = var.container_port

  protocol         = var.alb_protocol.protocol
  protocol_version = var.alb_protocol.version

  vpc_id      = var.vpc_id
  target_type = var.use_fargate ? "ip" : "instance"

  deregistration_delay = 60

  health_check {
    path     = var.health_check_path
    matcher  = var.health_check_matcher
    timeout  = var.health_check_timeout
    interval = var.health_check_interval
  }

  tags = local.tags
}
