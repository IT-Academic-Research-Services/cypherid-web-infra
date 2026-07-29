# Null-safe so the module still produces outputs when create_compute = false. cluster_id must stay a
# STRING, never null: dev/web and dev/resque pass it into required string variables (their services are
# gated off, so the value is unused -- but the argument is still mandatory). "" keeps them planning.
output "cluster_id" {
  value = try(aws_ecs_cluster.cluster[0].id, "")
}

output "security_group_id" {
  value = module.sg.security_group_id
}

output "logs_group_name" {
  value = module.logs.name
}

output "logs_group_arn" {
  value = module.logs.arn
}

output "asg_name" {
  value = try(aws_autoscaling_group.ecs[0].name, "")
}

output "cluster_name" {
  value = try(aws_ecs_cluster.cluster[0].name, "")
}

output "arn" {
  value = try(aws_ecs_cluster.cluster[0].arn, "")
}

output "ami_id" {
  value = local.ami
}

output "container_instance_role_arn" {
  value       = module.profile.role_name
  description = "The ec2 role run in the container instances. If using ECR, authorize this role for read access."
}

output "ecs" {
  value = {
    cluster_id     = try(aws_ecs_cluster.cluster[0].id, "")
    security_group = module.sg.security_group_id
    log_group      = module.logs.name
    cluster_name   = try(aws_ecs_cluster.cluster[0].name, "")
    subnets        = var.subnets
    vpc_id         = var.vpc_id
    region         = var.region
  }
}
