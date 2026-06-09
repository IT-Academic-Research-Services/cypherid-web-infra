output "cluster_id" {
  value = module.ecs-cluster.cluster_id
}

output "security_group_id" {
  value = module.ecs-cluster.security_group_id
}

output "s3_bucket_aegea_ecs_execute" {
  value = local.s3_bucket_aegea_ecs_execute
}
