locals {
  zone_id = data.terraform_remote_state.idseq-prod.outputs.idseq_net_zone_id
}

resource "aws_route53_record" "mailgun_mx" {
  zone_id = local.zone_id
  name    = "mg.idseq.net."
  type    = "MX"
  ttl     = "300"
  records = ["10 mxb.mailgun.org", "10 mxa.mailgun.org"]
}

resource "aws_route53_record" "mailgun_spf" {
  zone_id = local.zone_id
  name    = "mg.idseq.net."
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:mailgun.org ~all"]
}

resource "aws_route53_record" "mailgun_domain_key" {
  zone_id = local.zone_id
  name    = "smtp._domainkey.mg.idseq.net."
  type    = "TXT"
  ttl     = "300"
  records = ["k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDQVezIq5AawfIQz/vnJcPRMQSJmIHTFWcWi5pFZulfpcK3/9/pZIgVPIOdwBr0G3Gqe6I5dPmIhn1wYo7CqNNDfv5CDVZLS5hyWHY6kBM4T3R652ly8CZVQJPf6Sm1YpKrkTftvBXnsN7t9M773IZZ1uYsu8lBktkPRJPqYsQRmQIDAQAB"]
}
