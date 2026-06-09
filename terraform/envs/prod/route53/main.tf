locals {
  happy_fqdn = "happy.${var.base_domain}"
}

# domain registration

# TODO: Make sure this contains the nameservers from aws_route53_zone.root-seqtoid-org
# resource "aws_route53domains_registered_domain" "seqtoid-org" {
#   domain_name = var.base_domain
# }
#
# import {
#   to = aws_route53domains_registered_domain.seqtoid-org
#   id = var.base_domain
# }

# root zone, which is the "prod" zone, but with no "prod" prefix

resource "aws_route53_zone" "seqtoid-org" {
  name = var.base_domain
}

# happy zone

resource "aws_route53_zone" "happy-seqtoid-org" {
  name = local.happy_fqdn
}

resource "aws_route53_record" "happy-seqtoid-org" {
  zone_id = aws_route53_zone.seqtoid-org.id
  name    = local.happy_fqdn
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.happy-seqtoid-org.name_servers
}
