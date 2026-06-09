output "alb_dns_name" {
  value = module.alb.dns_name
}

output "alb_route53_zone_id" {
  value = module.alb.zone_id
}

output "ecs_task_definition_family" {
  description = "The family of the task definition defined for the given/generated container definition."
  value       = element(concat(aws_ecs_task_definition.fargate_job.*.family, aws_ecs_task_definition.job.*.family), 0)
}

output "container_security_group_id" {
  description = "Security group id for the container."
  value       = module.container-sg.security_group_id
}

output "private_service_discovery_domain" {
  description = "Domain name for service discovery, if with_service_discovery=true. Only resolvable within the VPC."
  value       = "${element(coalescelist(aws_service_discovery_service.discovery.*.name, [""]), 0)}${var.with_service_discovery ? "." : ""}${element(coalescelist(aws_service_discovery_private_dns_namespace.discovery.*.name, [""]), 0)}"
}

output "alb_access_logs_prefix" {
  description = "ALB access logs S3 prefix"
  value       = module.alb.access_logs_prefix
}
