output "bucket_name" {
  value = local.bucket_name
}

output "bucket_arn" {
  value = module.aws-bucket.arn
}
