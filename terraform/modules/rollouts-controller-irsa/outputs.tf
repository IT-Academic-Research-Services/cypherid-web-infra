output "role_arn" {
  description = "IAM role ARN for the Argo Rollouts controller. Annotate the controller service account with this (eks.amazonaws.com/role-arn) so --aws-verify-target-group can call elbv2 Describe*."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name for the Argo Rollouts controller."
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "ARN of the Argo Rollouts controller IAM policy."
  value       = aws_iam_policy.this.arn
}
