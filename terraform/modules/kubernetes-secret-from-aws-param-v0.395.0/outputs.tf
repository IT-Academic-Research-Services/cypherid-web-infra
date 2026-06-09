output "secret_name" {
  value = coalescelist(kubernetes_secret.secret[*].metadata[0].name, [""])[0]
}

output "role_name" {
  value = aws_iam_role.role.name
}

output "role_arn" {
  value = aws_iam_role.role.arn
}
