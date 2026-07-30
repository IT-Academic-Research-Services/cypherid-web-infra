variable "env" {
  type        = string
  description = "Deployment environment: dev | staging | prod."
}

variable "service" {
  type        = string
  description = "Logical static-site service name, e.g. web-assets | helpcenter. Used to name the bucket (seqtoid-<service>-<env>) and tag resources."
}

variable "domain" {
  type        = string
  description = "Fully-qualified domain the site is served from, e.g. assets.staging.seqtoid.org. Used as the CloudFront alias and ACM certificate domain."
}

variable "zone_id" {
  type        = string
  description = "Route53 hosted zone ID for seqtoid.org. The caller wires this from the route53 remote state (exact output key resolved in STATIC-002 discovery)."
}

variable "glacier_noncurrent" {
  type        = bool
  default     = false
  description = <<-EOT
    When true, transition noncurrent object versions to GLACIER_IR after 30 days.
    Marginal benefit at this scale — 128KB min billable object size, 90-day min
    storage duration; most static assets are smaller than 128KB so the transition
    may not fire. Off by default. TODO(STATIC-001): ref cost analysis before enabling.
  EOT
}

variable "web_acl_id" {
  type        = string
  default     = null
  description = <<-EOT
    ARN of a CLOUDFRONT-scoped WAFv2 Web ACL to attach. Injected by the env stack
    from its cloudfront-web-acl module (created in us-east-1); the REGIONAL web-waf
    cannot attach to CloudFront. Optional — null leaves the distribution without a WAF.
  EOT
}

variable "log_bucket_domain_name" {
  type        = string
  default     = null
  description = <<-EOT
    S3 bucket domain name (e.g. name.s3.amazonaws.com) for CloudFront standard
    access logs. Injected by the env stack from its cloudfront-access-logs module.
    Optional — when null, the distribution's logging_config is omitted.
  EOT
}

variable "log_prefix" {
  type        = string
  default     = null
  description = "Key prefix for CloudFront access logs written to var.log_bucket_domain_name. Optional."
}

variable "response_headers_policy_id" {
  type        = string
  default     = null
  description = <<-EOT
    ID of a CloudFront response-headers policy to attach to the default cache
    behavior. Injected by the env stack from its cloudfront-security-headers module.
    Optional — null leaves the default (no policy).
  EOT
}

variable "s3_log_bucket_name" {
  type        = string
  default     = null
  description = <<-EOT
    Name of an S3 bucket to receive server access logs for the static-asset bucket.
    Injected by the env stack. Optional — when null, no aws_s3_bucket_logging is created.
  EOT
}

variable "enable_index_rewrite" {
  type        = bool
  default     = false
  description = "rewrite extensionless URIs to /index.html; needed for static sites with per-directory index files"
}
