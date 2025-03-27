locals {
  domain = "czid.org"
}

// CZ ID zone and records
resource "aws_route53_zone" "czid-org" {
  name = local.domain

  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "prod"
  }
}

resource "aws_route53_record" "dev-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "dev.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.dev_czid_org_name_servers
}

resource "aws_route53_record" "staging-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "staging.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.staging_czid_org_name_servers
}

resource "aws_route53_record" "sandbox-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "sandbox.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.sandbox_czid_org_name_servers
}

resource "aws_route53_record" "public-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "public.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.public_czid_org_name_servers
}

// IDseq zone and records
resource "aws_route53_zone" "idseq-net" {
  name = "idseq.net"
  tags = {
    owner   = var.owner
    project = var.project
    service = "idseq"
    env     = "prod"
  }
}

resource "aws_route53_record" "dev-idseq-net" {
  zone_id = aws_route53_zone.idseq-net.id
  name    = "dev.idseq.net"
  type    = "NS"
  ttl     = 60
  # Hardcoded to the NS for Z0379240WLNLLBX17QK2 managed by this module in idseq-dev.
  records = [
    "ns-1064.awsdns-05.org",
    "ns-1612.awsdns-09.co.uk",
    "ns-253.awsdns-31.com",
    "ns-850.awsdns-42.net"
  ]
}

resource "aws_route53_record" "staging-idseq-net" {
  zone_id = aws_route53_zone.idseq-net.id
  name    = "staging.idseq.net"
  type    = "NS"
  ttl     = 60
  # Hardcoded to the NS for Z00298292O974O1XBFE5D managed by this module in idseq-dev.
  records = [
    "ns-1065.awsdns-05.org",
    "ns-1949.awsdns-51.co.uk",
    "ns-55.awsdns-06.com",
    "ns-874.awsdns-45.net"
  ]
}

resource "aws_route53_record" "sandbox-idseq-net" {
  zone_id = aws_route53_zone.idseq-net.id
  name    = "sandbox.idseq.net"
  type    = "NS"
  ttl     = 60
  # Hardcoded to the NS for Z04231392IGN61BKQXN8X managed by this module in idseq-dev.
  records = [
    "ns-1412.awsdns-48.org",
    "ns-2044.awsdns-63.co.uk",
    "ns-438.awsdns-54.com",
    "ns-747.awsdns-29.net"
  ]
}

resource "aws_route53_record" "meta-sandbox-idseq-net" {
  zone_id = aws_route53_zone.idseq-net.id
  name    = "meta.sandbox.idseq.net"
  type    = "NS"
  ttl     = 60
  # Hardcoded to the NS for Z00585311J3V8OBW2U8YE managed by this module in idseq-dev.
  records = [
    "ns-754.awsdns-30.net",
    "ns-1478.awsdns-56.org",
    "ns-417.awsdns-52.com",
    "ns-1586.awsdns-06.co.uk"
  ]
}

locals {
  email_configuration = [
    # domain ownership verification for amazonses
    ["TXT", "_amazonses.idseq.net.", ["y2EoQeOFR2IcKdinNxKfDsDt/q1cmxrXOGulh54oPRk="]],
    # workmail validation entries
    ["MX", "idseq.net.", ["10 inbound-smtp.us-west-2.amazonaws.com."]],
    ["CNAME", "autodiscover.idseq.net.", ["autodiscover.mail.us-west-2.awsapps.com."]],
    # Amazon SES authentication
    ["CNAME", "jrlrt7jd3hpmvp45i4yymesal5cdqztj._domainkey.idseq.net.", ["jrlrt7jd3hpmvp45i4yymesal5cdqztj.dkim.amazonses.com."]],
    ["CNAME", "27fwgrc2ycj53rmki724f7km6agc74z6._domainkey.idseq.net.", ["27fwgrc2ycj53rmki724f7km6agc74z6.dkim.amazonses.com."]],
    ["CNAME", "hi5uhr6isqgyngeobkie2c3cmwdh3rfz._domainkey.idseq.net.", ["hi5uhr6isqgyngeobkie2c3cmwdh3rfz.dkim.amazonses.com."]],
    ["TXT", "_dmarc.idseq.net.", ["v=DMARC1;p=quarantine;pct=100;fo=1"]],
    ["SPF", "idseq.net.", ["v=spf1 mx a ptr include:mail.zendesk.com include:amazonses.com"]],
    ["TXT", "idseq.net.", [
      "v=spf1 mx a ptr include:mail.zendesk.com include:amazonses.com",
      "google-site-verification=gDyNKYMs8EWyxwwjq6EFZo2Cjq0CTkP-ai-fArBlKK0"
    ]],
  ]
}

resource "aws_route53_record" "email_configuration" {
  for_each = { for v in local.email_configuration : "${v[0]}|${v[1]}" => v }

  zone_id = aws_route53_zone.idseq-net.id
  type    = each.value[0]
  name    = each.value[1]
  records = each.value[2]
  ttl     = 60
}


locals {
  czid_auth0_custom_domain_configuration = [
    ["CNAME", "login-dev.czid.org.", ["czi-idseq-dev-cd-iasy2ip607mzlfc0.edge.tenants.auth0.com"]],
    ["CNAME", "login-staging.czid.org.", ["czi-idseq-staging-cd-v2yjsz7gzj735v30.edge.tenants.auth0.com"]],
    ["CNAME", "login.czid.org.", ["czi-idseq-prod-cd-pfygqmwijxjozjsj.edge.tenants.auth0.com"]]
  ]
}

resource "aws_route53_record" "czid_auth0_configuration" {
  for_each = { for v in local.czid_auth0_custom_domain_configuration : "${v[0]}|${v[1]}" => v }

  zone_id = aws_route53_zone.czid-org.id
  type    = each.value[0]
  name    = each.value[1]
  records = each.value[2]
  ttl     = 300
}

locals {
  czid_email_configuration = [
    # workmail validation entries
    ["MX", "czid.org.", ["10 inbound-smtp.us-west-2.amazonaws.com."]],
    ["CNAME", "autodiscover.czid.org.", ["autodiscover.mail.us-west-2.awsapps.com."]],
    # Amazon SES authentication
    ["TXT", "_dmarc.czid.org.", ["v=DMARC1;p=quarantine;pct=100;fo=1"]],
    ["SPF", "czid.org.", ["v=spf1 mx a ptr include:mail.zendesk.com include:amazonses.com include:7272273.spf07.hubspotemail.net"]],
    ["TXT", "zendeskverification.czid.org", ["7ddbd8b8a71114fc"]],
    ["TXT", "czid.org.", [
      "v=spf1 mx a ptr include:mail.zendesk.com include:amazonses.com",
      "google-site-verification=l4ByRW-4oFXy8LrPSNcBp4ew-FUuEkeMTkgmNRtQjPk"
    ]],
    # HubSpot
    ["CNAME", "hs1-7272273._domainkey.czid.org", ["czid-org.hs06a.dkim.hubspotemail.net."]],
    ["CNAME", "hs2-7272273._domainkey.czid.org", ["czid-org.hs06b.dkim.hubspotemail.net."]],
    # Google verification
    ["CNAME", "7x4bukxbid3h.czid.org", ["gv-e2otxyex64elb5.dv.googlehosted.com"]],
  ]
}

resource "aws_route53_record" "czid_email_configuration" {
  for_each = { for v in local.czid_email_configuration : "${v[0]}|${v[1]}" => v }

  zone_id = aws_route53_zone.czid-org.id
  type    = each.value[0]
  name    = each.value[1]
  records = each.value[2]
  ttl     = 60
}
//
//
// Prod happy zone and records
resource "aws_route53_zone" "prod-happy-czid-org" {
  name = "prod.happy.${local.domain}"

  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "prod"
  }
}

resource "aws_route53_record" "prod-happy-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = aws_route53_zone.prod-happy-czid-org.name
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.prod-happy-czid-org.name_servers
}

resource "aws_route53_record" "dev-happy-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "dev.happy.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.dev_happy_czid_org_name_servers
}

resource "aws_route53_record" "sandbox-happy-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "sandbox.happy.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.sandbox_happy_czid_org_name_servers
}

resource "aws_route53_record" "staging-happy-czid-org" {
  zone_id = aws_route53_zone.czid-org.id
  name    = "staging.happy.czid.org"
  type    = "NS"
  ttl     = 300
  records = data.terraform_remote_state.idseq-dev.outputs.staging_happy_czid_org_name_servers
}
