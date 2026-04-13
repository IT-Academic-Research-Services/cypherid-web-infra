locals {
  env_fqdn       = "${var.env}.${var.base_domain}"
  happy_env_fqdn = "happy.${local.env_fqdn}"
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

# root zone

resource "aws_route53_zone" "root-seqtoid-org" {
  name = var.base_domain
}

# prod zone

resource "aws_route53_zone" "env-seqtoid-org" {
  name = local.env_fqdn
}

resource "aws_route53_record" "env-seqtoid-org" {
  zone_id  = aws_route53_zone.root-seqtoid-org.zone_id
  name     = local.env_fqdn
  type     = "NS"
  ttl      = 300
  records  = aws_route53_zone.env-seqtoid-org.name_servers
  provider = aws.czi-si-us-east-1
}

# happy.prod zone

resource "aws_route53_zone" "happy-env-seqtoid-org" {
  name = local.happy_env_fqdn
}

resource "aws_route53_record" "happy-env-seqtoid-org" {
  zone_id = aws_route53_zone.env-seqtoid-org.id
  name    = local.happy_env_fqdn
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.happy-env-seqtoid-org.name_servers
}
