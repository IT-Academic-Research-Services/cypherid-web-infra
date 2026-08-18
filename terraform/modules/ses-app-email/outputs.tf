output "domain_identity_arn" {
  value       = aws_sesv2_email_identity.domain.arn
  description = "ARN of the SES sending-domain identity."
}

output "from_address" {
  value       = local.from_address
  description = "The verified From address to set as MAIL_FROM_ADDRESS in the app."
}

output "dkim_tokens" {
  value       = aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens
  description = "Easy-DKIM tokens (also published as CNAMEs by this module)."
}

output "smtp_user" {
  value       = aws_iam_access_key.ses_smtp.id
  description = "SMTP_USER for the app (SES SMTP username = the IAM access key id)."
}

output "smtp_password" {
  value       = aws_iam_access_key.ses_smtp.ses_smtp_password_v4
  sensitive   = true
  description = "SMTP_PASSWORD for the app (SES SMTP password derived from the IAM secret). Set in chamber; never commit."
}

output "support_recipient_verification_pending" {
  value       = var.verify_support_recipient ? "A verification email was sent to ${var.support_inbox_email} -- it must be clicked before SES (sandbox) will deliver there." : "recipient verification disabled"
  description = "Sandbox recipient-verification reminder."
}
