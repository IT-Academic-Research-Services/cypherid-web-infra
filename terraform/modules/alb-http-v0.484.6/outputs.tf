output "dns_name" {
  value = local.alb_dns_name
}

output "zone_id" {
  value = local.alb_zone_id
}

output "security_group_id" {
  description = "Generated security group ID. If create_security_group is false, this will be empty."
  value       = module.sg.security_group_id
}

output "access_logs_prefix" {
  description = "S3 alb access logs prefix"
  value       = local.access_logs_prefix
}
