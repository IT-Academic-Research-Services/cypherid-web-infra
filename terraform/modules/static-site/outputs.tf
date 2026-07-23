output "bucket_name" {
  value       = aws_s3_bucket.this.bucket
  description = "Name of the S3 bucket backing the static site."
}

output "distribution_id" {
  value       = aws_cloudfront_distribution.this.id
  description = "ID of the CloudFront distribution."
}

output "distribution_domain" {
  value       = aws_cloudfront_distribution.this.domain_name
  description = "CloudFront distribution domain name (e.g. dxxxx.cloudfront.net)."
}

output "fqdn" {
  value       = var.domain
  description = "Fully-qualified domain the site is served from."
}

output "oai_iam_arn" {
  value       = aws_cloudfront_origin_access_identity.this.iam_arn
  description = "IAM ARN of the CloudFront origin access identity granted read on the bucket."
}
