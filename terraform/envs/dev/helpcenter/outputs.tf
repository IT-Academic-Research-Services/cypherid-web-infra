output "bucket_name" {
  value = module.static_site.bucket_name
}

output "distribution_id" {
  value = module.static_site.distribution_id
}

output "distribution_domain" {
  value = module.static_site.distribution_domain
}

output "fqdn" {
  value = module.static_site.fqdn
}

output "oai_iam_arn" {
  value = module.static_site.oai_iam_arn
}
