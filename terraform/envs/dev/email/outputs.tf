output "from_address" {
  value       = module.email.from_address
  description = "Set as MAIL_FROM_ADDRESS in the app's chamber."
}

output "support_recipient_verification_pending" {
  value = module.email.support_recipient_verification_pending
}
