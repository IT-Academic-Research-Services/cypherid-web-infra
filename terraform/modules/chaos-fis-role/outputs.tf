output "role_arn" {
  description = "ARN of the role AWS FIS assumes for chaos experiments."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the FIS chaos role."
  value       = aws_iam_role.this.name
}
