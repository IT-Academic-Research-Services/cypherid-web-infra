output "on_call_role_arn" {
  value       = aws_iam_role.on_call.arn
  description = "ARN of the on call role"
}

output "comp_bio_role_arn" {
  value       = aws_iam_role.comp_bio.arn
  description = "ARN of the on call role"
}
