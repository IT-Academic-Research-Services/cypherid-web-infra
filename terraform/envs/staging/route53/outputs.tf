output "env_seqtoid_org_zone_id" {
  value = aws_route53_zone.env-seqtoid-org.zone_id
}

output "env_seqtoid_org_name_servers" {
  value = aws_route53_zone.env-seqtoid-org.name_servers
}

output "env_seqtoid_org_fqdn" {
  value = aws_route53_zone.env-seqtoid-org.name
}

# Happy environment zone outputs
output "happy_env_seqtoid_org_zone_id" {
  value = aws_route53_zone.happy-env-seqtoid-org.zone_id
}

output "happy_env_seqtoid_org_name_servers" {
  value = aws_route53_zone.happy-env-seqtoid-org.name_servers
}
