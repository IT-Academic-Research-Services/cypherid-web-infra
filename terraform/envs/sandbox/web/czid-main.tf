locals {
  czid_zone_id = data.terraform_remote_state.idseq-dev.outputs.sandbox_czid_org_zone_id
}

module "czid-sandbox-cert" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.41.0"

  cert_domain_name    = local.czid_origin_domain
  aws_route53_zone_id = local.czid_zone_id
  tags                = var.tags

  cert_subject_alternative_names = {
    "www.${local.czid_origin_domain}" = local.czid_zone_id
  }
}

module "czid-web-service" {
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/ecs-service-with-alb?ref=v0.421.0"

  service             = "web"
  project             = var.project_v1
  owner               = var.owner
  container_port      = 3000
  container_name      = "rails"
  env                 = var.env
  vpc_id              = data.terraform_remote_state.cloud-env.outputs.vpc_id
  cluster_id          = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn       = aws_iam_role.idseq-web.arn
  desired_count       = 2
  lb_subnets          = data.terraform_remote_state.cloud-env.outputs.public_subnets
  route53_zone_id     = local.czid_zone_id
  subdomain           = ""
  health_check_path   = "/health_check"
  acm_certificate_arn = module.czid-sandbox-cert.arn
  lb_egress_cidrs     = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  access_logs_bucket  = data.terraform_remote_state.elb-access-logs.outputs.bucket_name
  # The AWS and module default is 60s. We decided to increase it after observing
  # multiple endpoints exceeding that in production under normal loads, including
  # bulk_upload_with_metadata and report_csv.
  lb_idle_timeout_seconds = 300
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

resource "aws_route53_record" "czid-www" {
  zone_id = local.czid_zone_id
  name    = "www.${local.czid_origin_domain}"
  type    = "A"

  alias {
    name                   = module.czid-web-service.alb_dns_name
    zone_id                = module.czid-web-service.alb_route53_zone_id
    evaluate_target_health = false
  }
}
