output "gh_actions_executor_role" {
  value     = module.czid_web_private_gh_actions_executor.role
  sensitive = false
}

output "gh_actions_plan_role" {
  value     = module.czid_gh_actions_plan.role
  sensitive = false
}

output "gh_actions_apply_role" {
  value     = module.czid_gh_actions_apply.role
  sensitive = false
}

# SMP-1775: cross-account ECR-push role assumed by seqtoid-web's promote-to-env
# workflow. Its NAME is what the GitHub Environment var ENV_ECR_WRITE_ROLE must
# be set to (the workflow builds the full ARN from ENV_ACCOUNT_ID + this name).
output "gh_actions_ecr_push_role" {
  value     = module.czid_gh_actions_ecr_push.role
  sensitive = false
}
