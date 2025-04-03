output "cluster_id" {
  value = aws_ecs_cluster.cluster.id
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
  value = aws_autoscaling_group.ecs.name
}

output "cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "arn" {
  value = aws_ecs_cluster.cluster.arn
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
    cluster_id     = aws_ecs_cluster.cluster.id
    security_group = module.sg.security_group_id
    log_group      = module.logs.name
    cluster_name   = aws_ecs_cluster.cluster.name
    subnets        = var.subnets
    vpc_id         = var.vpc_id
    region         = var.region
  }
}
