# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.

output "additional_addons" {
  value     = module.k8s-core.additional_addons
  sensitive = true
}

output "aws_ssm_iam_role_name" {
  value     = module.k8s-core.aws_ssm_iam_role_name
  sensitive = false
}

output "datadog_agent_hostname" {
  value     = module.k8s-core.datadog_agent_hostname
  sensitive = false
}

output "default_namespace" {
  value     = module.k8s-core.default_namespace
  sensitive = false
}


