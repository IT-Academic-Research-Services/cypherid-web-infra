output "role_arn" {
  value = aws_iam_role.snowflake.arn
}

output "role_name" {
  value = aws_iam_role.snowflake.name
}
