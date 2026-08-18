output "from_address" {
  value       = module.email.from_address
  description = "Set as MAIL_FROM_ADDRESS in the app's chamber."
}

output "smtp_user" {
  value       = module.email.smtp_user
  description = "SMTP_USER for the app."
}

output "smtp_password" {
  value       = module.email.smtp_password
  sensitive   = true
  description = "SMTP_PASSWORD for the app (read via `terraform output -raw smtp_password`)."
}

output "support_recipient_verification_pending" {
  value = module.email.support_recipient_verification_pending
}
