output "repository_arn" {
  value     = module.aws-ecr-repo.repository_arn
  sensitive = false
}

output "repository_name" {
  value     = module.aws-ecr-repo.repository_name
  sensitive = false
}

output "repository_url" {
  value     = module.aws-ecr-repo.repository_url
  sensitive = false
}

output "trigged_by" {
  value = terraform_data.build_push_docker_img.triggers_replace
}
