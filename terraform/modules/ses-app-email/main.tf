locals {
  from_address     = "SeqToID <${var.from_local_part}@${var.env_fqdn}>"
  mail_from_domain = "${var.mail_from_subdomain}.${var.env_fqdn}"
  # Write chamber params only when a prefix is given AND (for the two optional observability
  # values) the value is non-empty.
  write_chamber = var.chamber_ssm_prefix != ""
}

# --- Sending domain identity + Easy DKIM ------------------------------------------------
resource "aws_sesv2_email_identity" "domain" {
  email_identity = var.env_fqdn
  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }
  tags = var.tags
}

# Publish the 3 Easy-DKIM CNAMEs so SES can verify the domain + sign outbound mail.
# count = 3 (Easy DKIM always emits exactly 3 tokens), NOT for_each over the tokens: the token
# VALUES are only known after the identity is created, and for_each keys must be known at plan
# time -- for_each over them errors "Invalid for_each argument". A static count sidesteps that.
resource "aws_route53_record" "dkim" {
  count = 3

  zone_id = var.zone_id
  name    = "${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${var.env_fqdn}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}

# --- Custom MAIL FROM (SPF alignment) ---------------------------------------------------
resource "aws_sesv2_email_identity_mail_from_attributes" "domain" {
  email_identity   = aws_sesv2_email_identity.domain.email_identity
  mail_from_domain = local.mail_from_domain
  # USE_DEFAULT_VALUE (fall back to amazonses.com) rather than REJECT, so a not-yet-propagated
  # MAIL FROM record never bounces a support email. SPF still aligns once the records below resolve.
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_route53_record" "mail_from_mx" {
  zone_id = var.zone_id
  name    = local.mail_from_domain
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.region}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  zone_id = var.zone_id
  name    = local.mail_from_domain
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com ~all"]
}

# DMARC in monitor mode (p=none): aggregate reports go to the support inbox; no enforcement,
# so it cannot cause a legitimate support email to be dropped. Tighten to quarantine/reject later.
resource "aws_route53_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc.${var.env_fqdn}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=none; rua=mailto:${var.support_inbox_email}"]
}

# --- Recipient verification (SES sandbox) -----------------------------------------------
# In the sandbox, SES can only send to verified recipients. Creating an email identity for the
# support inbox triggers a verification email to that mailbox; someone must click the link.
resource "aws_sesv2_email_identity" "support_recipient" {
  count          = var.verify_support_recipient ? 1 : 0
  email_identity = var.support_inbox_email
  tags           = var.tags
}

# --- Sending identity ONLY: no SMTP IAM user ---------------------------------------------
# The app sends via ActionMailer :sesv2 (the SESv2 SendEmail API), authenticating with the
# seqtoid-web pod's IRSA role -- the AWS default credential chain resolves to that role in-pod.
# So this module provisions the SES sending identity (above) but creates NO IAM user and NO
# long-lived SMTP access key. The ses:SendEmail/SendRawEmail grant lives on the web IRSA role
# in the web component (dev: terraform/envs/dev/web/eks-irsa-ses.tf; other envs: their own web
# IRSA stack), scoped to THIS domain identity + a no-reply@<env_fqdn> From address. This also
# removes the checkov CKV_AWS_273 long-lived-access-key finding entirely.

# --- Optional chamber wiring ------------------------------------------------------------
# The chamber SecureString CMK (alias "parameter_store_key" exists in every env account). The
# app's IRSA role grants kms:Decrypt on THIS key only, so these SecureString params must be
# encrypted with it or `chamber exec` cannot read them. Using the CMK (not the default aws/ssm
# key) also satisfies checkov CKV_AWS_337.
data "aws_kms_key" "chamber" {
  count  = local.write_chamber ? 1 : 0
  key_id = "alias/parameter_store_key"
}

# All chamber params are SecureString under the CMK -- matches how `chamber write` stores params
# (SecureString by default) and satisfies checkov CKV2_AWS_34/CKV_AWS_337. The app's IRSA grants
# kms:Decrypt on this key, so `chamber exec` reads them transparently. No SMTP_USER/SMTP_PASSWORD
# is written -- the app authenticates to SES with its IRSA role, not SMTP creds.
resource "aws_ssm_parameter" "mail_from_address" {
  count  = local.write_chamber ? 1 : 0
  name   = "${var.chamber_ssm_prefix}MAIL_FROM_ADDRESS"
  type   = "SecureString"
  key_id = data.aws_kms_key.chamber[0].id
  value  = local.from_address
  tags   = var.tags
}

resource "aws_ssm_parameter" "support_inbox_email" {
  count  = local.write_chamber ? 1 : 0
  name   = "${var.chamber_ssm_prefix}SUPPORT_INBOX_EMAIL"
  type   = "SecureString"
  key_id = data.aws_kms_key.chamber[0].id
  value  = var.support_inbox_email
  tags   = var.tags
}

resource "aws_ssm_parameter" "support_log_group" {
  count  = local.write_chamber && var.support_log_group != "" ? 1 : 0
  name   = "${var.chamber_ssm_prefix}SUPPORT_LOG_GROUP"
  type   = "SecureString"
  key_id = data.aws_kms_key.chamber[0].id
  value  = var.support_log_group
  tags   = var.tags
}

resource "aws_ssm_parameter" "otel_dashboard_base_url" {
  count  = local.write_chamber && var.otel_dashboard_base_url != "" ? 1 : 0
  name   = "${var.chamber_ssm_prefix}OTEL_DASHBOARD_BASE_URL"
  type   = "SecureString"
  key_id = data.aws_kms_key.chamber[0].id
  value  = var.otel_dashboard_base_url
  tags   = var.tags
}
