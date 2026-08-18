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
resource "aws_route53_record" "dkim" {
  for_each = toset(aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens)

  zone_id = var.zone_id
  name    = "${each.value}._domainkey.${var.env_fqdn}"
  type    = "CNAME"
  ttl     = 600
  records = ["${each.value}.dkim.amazonses.com"]
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

# --- SMTP credentials for ActionMailer :smtp --------------------------------------------
# The app is already wired for ActionMailer :smtp against the SES SMTP endpoint; it only lacks
# SMTP_USER/SMTP_PASSWORD. A dedicated IAM user (least privilege: SendRawEmail from THIS identity
# only) provides them. ses_smtp_password_v4 is the IAM secret converted to the SES SMTP password.
resource "aws_iam_user" "ses_smtp" {
  name = "seqtoid-${var.env_fqdn}-ses-smtp"
  path = "/ses/"
  tags = var.tags
}

data "aws_iam_policy_document" "ses_smtp" {
  statement {
    sid       = "SendFromVerifiedIdentityOnly"
    effect    = "Allow"
    actions   = ["ses:SendRawEmail", "ses:SendEmail"]
    resources = [aws_sesv2_email_identity.domain.arn]
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["${var.from_local_part}@${var.env_fqdn}"]
    }
  }
}

resource "aws_iam_user_policy" "ses_smtp" {
  name   = "ses-send"
  user   = aws_iam_user.ses_smtp.name
  policy = data.aws_iam_policy_document.ses_smtp.json
}

resource "aws_iam_access_key" "ses_smtp" {
  user = aws_iam_user.ses_smtp.name
}

# --- Optional chamber wiring ------------------------------------------------------------
resource "aws_ssm_parameter" "smtp_user" {
  count = local.write_chamber ? 1 : 0
  name  = "${var.chamber_ssm_prefix}SMTP_USER"
  type  = "String"
  value = aws_iam_access_key.ses_smtp.id
  tags  = var.tags
}

resource "aws_ssm_parameter" "smtp_password" {
  count = local.write_chamber ? 1 : 0
  name  = "${var.chamber_ssm_prefix}SMTP_PASSWORD"
  type  = "SecureString"
  value = aws_iam_access_key.ses_smtp.ses_smtp_password_v4
  tags  = var.tags
}

resource "aws_ssm_parameter" "mail_from_address" {
  count = local.write_chamber ? 1 : 0
  name  = "${var.chamber_ssm_prefix}MAIL_FROM_ADDRESS"
  type  = "String"
  value = local.from_address
  tags  = var.tags
}

resource "aws_ssm_parameter" "support_inbox_email" {
  count = local.write_chamber ? 1 : 0
  name  = "${var.chamber_ssm_prefix}SUPPORT_INBOX_EMAIL"
  type  = "String"
  value = var.support_inbox_email
  tags  = var.tags
}

resource "aws_ssm_parameter" "support_log_group" {
  count = local.write_chamber && var.support_log_group != "" ? 1 : 0
  name  = "${var.chamber_ssm_prefix}SUPPORT_LOG_GROUP"
  type  = "String"
  value = var.support_log_group
  tags  = var.tags
}

resource "aws_ssm_parameter" "otel_dashboard_base_url" {
  count = local.write_chamber && var.otel_dashboard_base_url != "" ? 1 : 0
  name  = "${var.chamber_ssm_prefix}OTEL_DASHBOARD_BASE_URL"
  type  = "String"
  value = var.otel_dashboard_base_url
  tags  = var.tags
}
