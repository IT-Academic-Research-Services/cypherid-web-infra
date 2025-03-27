output "czid_org_zone_id" {
  value = aws_route53_zone.czid-org.zone_id
}

output "czid_org_name_servers" {
  value = aws_route53_zone.czid-org.name_servers
}

output "idseq_net_zone_id" {
  value = aws_route53_zone.idseq-net.zone_id
}

output "idseq_net_name_servers" {
  value = aws_route53_zone.idseq-net.name_servers
}

output "prod_happy_czid_org_zone_id" {
  value = aws_route53_zone.prod-happy-czid-org.zone_id
}

output "prod_happy_czid_org_name_servers" {
  value = aws_route53_zone.prod-happy-czid-org.name_servers
}
