output "env_seqtoid_org_zone_id" {
  value = aws_route53_zone.seqtoid-org.zone_id
}

output "env_seqtoid_org_fqdn" {
  value = aws_route53_zone.seqtoid-org.name
}

output "happy_env_seqtoid_org_zone_id" {
  value = aws_route53_zone.happy-seqtoid-org.zone_id
}

output "happy_env_seqtoid_org_zone_fqdn" {
  value = aws_route53_zone.happy-seqtoid-org.name
}
