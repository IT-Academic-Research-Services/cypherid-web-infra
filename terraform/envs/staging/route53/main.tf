locals {
  env_fqdn       = "${var.env}.${var.base_domain}"
  happy_env_fqdn = "happy.${local.env_fqdn}"
}

resource "aws_route53_zone" "env-seqtoid-org" {
  name = local.env_fqdn
}

data "aws_route53_zone" "root-seqtoid-org" {
  name         = var.base_domain
  private_zone = false
  provider     = aws.czi-si-us-east-1
}

resource "aws_route53_record" "env-seqtoid-org" {
  zone_id  = data.aws_route53_zone.root-seqtoid-org.zone_id
  name     = local.env_fqdn
  type     = "NS"
  ttl      = 300
  records  = aws_route53_zone.env-seqtoid-org.name_servers
  provider = aws.czi-si-us-east-1
}

# Zones for happy dev/sandbox/staging envs

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
