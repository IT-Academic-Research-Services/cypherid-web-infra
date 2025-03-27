output "elasticache_secure_dns_name" {
  value = module.elasticache_secure.primary_endpoint_address
}
