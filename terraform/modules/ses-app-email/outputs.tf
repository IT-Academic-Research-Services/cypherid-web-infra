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

output "support_recipient_verification_pending" {
  value       = var.verify_support_recipient ? "A verification email was sent to ${var.support_inbox_email} -- it must be clicked before SES (sandbox) will deliver there." : "recipient verification disabled"
  description = "Sandbox recipient-verification reminder."
}
