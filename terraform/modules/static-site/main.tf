locals {
  bucket_name = "seqtoid-${var.service}-${var.env}"

  # project + owner are injected globally by the fogg provider `default_tags`
  # (see envs/*/web/fogg.tf); we only set the resource-specific tags here.
  tags = {
    env       = var.env
    service   = var.service
    managedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# CloudFront origin access identity (OAI)
# ---------------------------------------------------------------------------
# Repo convention (maintenance/main.tf) uses the legacy OAI + bucket policy.
# TODO(STATIC-001): migrating to origin access control (OAC) is a planned
# mechanical swap for a later ticket; no OAC precedent exists in this repo yet.
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "OAI for seqtoid-${var.service}-${var.env}"
}

# ---------------------------------------------------------------------------
# S3 bucket + hardening
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  # checkov:skip=CKV2_AWS_62:event notifications are not required for a static-asset bucket
  # checkov:skip=CKV_AWS_144:cross-region replication is not required; assets are rebuildable from source and republished by the deploy pipeline
  # checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is the deliberate choice; SSE-KMS with an OAI origin requires granting the OAI kms:Decrypt
  bucket = local.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3, not KMS
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Grant read access only to the CloudFront OAI. Everything else is denied
# implicitly (no other principals) plus the public access block above.
# Mirrors the policy structure in maintenance/main.tf.
data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "AllowCloudFrontOAIRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.this.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Rule 1 (always on): expire noncurrent versions after 365 days and clean up
  # expired object delete markers.
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    expiration {
      expired_object_delete_marker = true
    }

    # CKV_AWS_300: clean up storage from failed/abandoned multipart uploads.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Rule 2 (conditional on var.glacier_noncurrent): transition noncurrent
  # versions to GLACIER_IR after 30 days.
  # Marginal benefit at this scale — 128KB min billable object size, 90-day
  # min storage duration; most static assets are smaller than 128KB so the
  # transition may not fire. Off by default. TODO(STATIC-001): ref cost
  # analysis before enabling.
  dynamic "rule" {
    for_each = var.glacier_noncurrent ? [1] : []

    content {
      id     = "transition-noncurrent-to-glacier-ir"
      status = "Enabled"

      filter {}

      noncurrent_version_transition {
        noncurrent_days = 30
        storage_class   = "GLACIER_IR"
      }
    }
  }
}

# CKV_AWS_18: S3 server access logging, wired only when the env stack passes a
# destination bucket (mirrors the optional-injection pattern used for the WAF
# and access-logs above).
resource "aws_s3_bucket_logging" "this" {
  count = var.s3_log_bucket_name != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.s3_log_bucket_name
  target_prefix = "s3-access/${local.bucket_name}/"
}

# ---------------------------------------------------------------------------
# ACM certificate (CloudFront requires us-east-1) + DNS validation
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "this" {
  provider = aws.us-east-1

  domain_name               = var.domain
  validation_method         = "DNS"
  subject_alternative_names = [] # single domain only

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ---------------------------------------------------------------------------
# CloudFront distribution
# ---------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "this" {
  # checkov:skip=CKV2_AWS_47:WAF ARN is injected via var.web_acl_id from the env stack's cloudfront-web-acl module (see terraform/envs/dev/web/assets.tf:36); checkov's connection-graph check cannot resolve the wafv2 across the variable boundary
  # checkov:skip=CKV2_AWS_32:response-headers policy is created by the env stack's cloudfront-security-headers module and injected via var.response_headers_policy_id; checkov's connection-graph check cannot resolve it across the variable boundary
  # checkov:skip=CKV_AWS_310:single S3 origin by design; origin failover is not applicable to a static-asset distribution
  # checkov:skip=CKV_AWS_374:geo restriction is intentionally "none"; public static assets must serve globally, matching every existing distribution in this repo
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Serves seqtoid-${var.service}-${var.env} static site from S3"

  aliases = [var.domain]

  # CLOUDFRONT-scoped WAFv2 ACL ARN, injected by the env stack from its
  # cloudfront-web-acl module (us-east-1). Optional — null attaches no WAF.
  web_acl_id = var.web_acl_id

  # CloudFront standard access logging (CKV_AWS_86), wired only when the env
  # stack passes a log bucket from its cloudfront-access-logs module.
  dynamic "logging_config" {
    for_each = var.log_bucket_domain_name != null ? [1] : []

    content {
      bucket          = var.log_bucket_domain_name
      include_cookies = false
      prefix          = var.log_prefix
    }
  }

  origin {
    domain_name = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.this.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.this.bucket_regional_domain_name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Security response-headers policy, injected by the env stack from its
    # cloudfront-security-headers module. Optional — null attaches no policy.
    response_headers_policy_id = var.response_headers_policy_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Route53 alias record for the site
# ---------------------------------------------------------------------------
resource "aws_route53_record" "this" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
