output "task_role_arn" {
  value = aws_iam_role.idseq-web.arn
}

# STATIC-002a: shared CloudFront edge outputs consumed by the static-asset
# components (STATIC-002b) via remote state, so they reuse this env's existing
# WAF, access-logs bucket, and security-headers policy instead of creating their own.
output "cloudfront_web_acl_id" {
  value       = module.cloudfront_waf.web_acl_id
  description = "ARN of the CLOUDFRONT-scoped WAFv2 Web ACL fronting this env's web CloudFront; static-asset components attach the same WAF."
}

output "cloudfront_access_logs_bucket_domain_name" {
  value       = module.cloudfront_access_logs.bucket_domain_name
  description = "S3 bucket domain name (name.s3.amazonaws.com) for CloudFront standard access logs; used as the static-asset distribution logging_config.bucket."
}

output "cloudfront_access_logs_bucket_name" {
  value       = module.cloudfront_access_logs.bucket_name
  description = "Plain name of the CloudFront access-logs S3 bucket; used as the static-asset S3 server-access logging target bucket."
}

output "cloudfront_response_headers_policy_id" {
  value       = module.security_headers.policy_id
  description = "ID of the shared CloudFront response-headers policy for this env; static-asset components attach the same security headers."
}
