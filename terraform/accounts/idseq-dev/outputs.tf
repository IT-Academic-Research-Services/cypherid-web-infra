// Outputs for new CZ ID zones

output "dev_czid_org_zone_id" {
  value = aws_route53_zone.dev-czid-org.zone_id
}

output "dev_czid_org_name_servers" {
  value = aws_route53_zone.dev-czid-org.name_servers
}

output "staging_czid_org_zone_id" {
  value = aws_route53_zone.staging-czid-org.zone_id
}

output "staging_czid_org_name_servers" {
  value = aws_route53_zone.staging-czid-org.name_servers
}

output "sandbox_czid_org_zone_id" {
  value = aws_route53_zone.sandbox-czid-org.zone_id
}

output "sandbox_czid_org_name_servers" {
  value = aws_route53_zone.sandbox-czid-org.name_servers
}

output "public_czid_org_zone_id" {
  value = aws_route53_zone.public-czid-org.zone_id
}

output "public_czid_org_name_servers" {
  value = aws_route53_zone.public-czid-org.name_servers
}

// Outputs for old IDseq zones

output "dev_idseq_net_zone_id" {
  value = aws_route53_zone.dev-idseq-net.zone_id
}

output "dev_idseq_net_name_servers" {
  value = aws_route53_zone.dev-idseq-net.name_servers
}

output "staging_idseq_net_zone_id" {
  value = aws_route53_zone.staging-idseq-net.zone_id
}

output "staging_idseq_net_name_servers" {
  value = aws_route53_zone.staging-idseq-net.name_servers
}

output "sandbox_idseq_net_zone_id" {
  value = aws_route53_zone.sandbox-idseq-net.zone_id
}

output "sandbox_idseq_net_name_servers" {
  value = aws_route53_zone.sandbox-idseq-net.name_servers
}

output "meta_sandbox_idseq_net_zone_id" {
  value = aws_route53_zone.meta-sandbox-idseq-net.zone_id
}

output "meta_sandbox_idseq_net_name_servers" {
  value = aws_route53_zone.meta-sandbox-idseq-net.name_servers
}

output "public_idseq_net_zone_id" {
  value = aws_route53_zone.public-idseq-net.zone_id
}

output "public_idseq_net_name_servers" {
  value = aws_route53_zone.public-idseq-net.name_servers
}

output "idseq_net_zone_id" {
  value = aws_route53_zone.dev-idseq-net.zone_id
}

# Happy environment zone outputs
output "dev_happy_czid_org_zone_id" {
  value = aws_route53_zone.dev-happy-czid-org.zone_id
}

output "dev_happy_czid_org_name_servers" {
  value = aws_route53_zone.dev-happy-czid-org.name_servers
}

output "sandbox_happy_czid_org_zone_id" {
  value = aws_route53_zone.sandbox-happy-czid-org.zone_id
}

output "sandbox_happy_czid_org_name_servers" {
  value = aws_route53_zone.sandbox-happy-czid-org.name_servers
}

output "staging_happy_czid_org_zone_id" {
  value = aws_route53_zone.staging-happy-czid-org.zone_id
}

output "staging_happy_czid_org_name_servers" {
  value = aws_route53_zone.staging-happy-czid-org.name_servers
}
