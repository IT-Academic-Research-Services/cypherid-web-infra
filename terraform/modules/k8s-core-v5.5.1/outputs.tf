output "default_namespace" {
  description = "Default namespace for applications to install into."
  value       = kubernetes_namespace.default_namespace.metadata[0].name
}

# output "aws_ssm_iam_role_name" {
#   value = module.aws-ssm.aws_ssm_iam_role_name
# }

output "datadog_agent_hostname" {
  value = one(module.datadog[*].datadog_agent_hostname)
}

output "additional_addons" {
  value     = var.additional_addons
  sensitive = true
}
