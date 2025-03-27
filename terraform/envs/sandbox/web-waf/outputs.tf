output "snowflake_reader_role" {
  value       = module.snowflake-ingest.role_arn
  description = "IAM role used to pipe WAF logs to Snowflake"
}

output "waf_bucket" {
  value       = module.web-service-waf.web_acl_log_bucket
  description = "the bucket that holds the WAF logs"
}
