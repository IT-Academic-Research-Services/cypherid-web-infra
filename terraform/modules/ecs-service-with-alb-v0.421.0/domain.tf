locals {
  fqdn = join(".", compact(tolist([var.subdomain, data.aws_route53_zone.zone.name])))
}

data "aws_route53_zone" "zone" {
  zone_id = var.route53_zone_id
}

resource "aws_route53_record" "ipv4" {
  # When the edge moves to a Kubernetes Ingress, the AWS load-balancer controller creates its own
  # ALB and external-dns owns these records -- but this module still declared them, pointing at the
  # ECS ALB. Terraform did not know it had lost ownership, so a refreshed plan wanted to drag
  # dev.seqtoid.org back to an ECS ALB with ZERO healthy targets: an outage, reported as "converged"
  # for as long as plans ran with -refresh=false. Set manage_dns_records = false wherever the Ingress
  # owns the edge. Defaults true, so ECS-fronted envs are unchanged. See platform-overhaul #693.
  count = var.manage_dns_records ? 1 : 0

  zone_id = var.route53_zone_id
  name    = local.fqdn
  type    = "A"

  allow_overwrite = false

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

# The following DNS records only exist if doing HTTP redirect

resource "aws_route53_record" "ipv6" {
  count   = var.manage_dns_records && !var.disable_http_redirect ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.fqdn
  type    = "AAAA"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www-ipv4" {
  count   = var.manage_dns_records && !var.disable_http_redirect ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "www.${local.fqdn}"
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www-ipv6" {
  count   = var.manage_dns_records && !var.disable_http_redirect ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "www.${local.fqdn}"
  type    = "AAAA"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}
