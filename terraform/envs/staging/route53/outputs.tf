output "env_seqtoid_org_zone_id" {
  value = aws_route53_zone.env-seqtoid-org.zone_id
}

output "env_seqtoid_org_fqdn" {
  value = aws_route53_zone.env-seqtoid-org.name
}

output "happy_env_seqtoid_org_zone_id" {
  value = aws_route53_zone.happy-env-seqtoid-org.zone_id
}

output "happy_env_seqtoid_org_zone_fqdn" {
  value = aws_route53_zone.happy-env-seqtoid-org.name
}
