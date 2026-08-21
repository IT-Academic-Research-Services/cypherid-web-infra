locals {
  full_domain = "${var.component}.${data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn}"
  zone_id     = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id

  aliases = {
    "www.${local.full_domain}" = local.zone_id
  }
}

resource "aws_s3_bucket" "maintenance_bucket" {
  bucket        = local.full_domain
  force_destroy = true
}

# Inline `acl` and `website` were deprecated in AWS provider v4 and moved to
# dedicated `aws_s3_bucket_*` resources (#475). Apply-safe: no bucket recreation.
#
# The aws_s3_bucket_acl "private" resource was REMOVED: S3 disables ACLs by default
# (ObjectOwnership = BucketOwnerEnforced) since April 2023, so PutBucketAcl now fails
# outright (400 InvalidArgument) and would take the whole maintenance stack's apply down.
# A "private" canned ACL was always a no-op here anyway -- the bucket is private by
# default and read access is granted solely by the CloudFront OAC bucket policy below.
# Same fix as ecs/aegea-ecs-execute and db/samples. See #687.

resource "aws_s3_bucket_website_configuration" "maintenance_bucket" {
  bucket = aws_s3_bucket.maintenance_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}


# CZID-359 (#359): OAC (Origin Access Control) replaces the legacy OAI. The bucket policy now grants
# the CloudFront service principal, scoped by AWS:SourceArn to THIS distribution only, so the origin
# bucket is locked to this distribution rather than to an OAI identity.
data "aws_iam_policy_document" "s3_iam_policy" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.maintenance_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.maintenance_bucket.id
  policy = data.aws_iam_policy_document.s3_iam_policy.json
}

module "assets-cert" {
  source = "../../../modules/aws-acm-certificate-v0.104.2" # cztack v0.104.2

  cert_domain_name               = local.full_domain
  aws_route53_zone_id            = local.zone_id
  cert_subject_alternative_names = local.aliases
  tags                           = var.tags # TODO: var.tags is deprecated

  # cloudfront requires us-east-1 acm certs
  providers = {
    aws = aws.us-east-1
  }
}

# CZID-359 (#359): Origin Access Control (OAC) — the modern replacement for OAI. SigV4-signed origin
# requests to S3; the bucket policy above is locked to this distribution via AWS:SourceArn.
resource "aws_cloudfront_origin_access_control" "s3_origin_access_control" {
  name                              = "${var.project}-${var.env}-${var.component}-oac"
  description                       = "OAC for the ${var.env} maintenance page S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_distribution" "distribution" {

  enabled             = true
  default_root_object = "index.html"
  comment             = "Serves ${var.env} maintenance page from S3 bucket"

  # CZID-61 (#61): CloudFront standard access logging to a private S3 bucket (CKV_AWS_86).
  logging_config {
    bucket          = module.cloudfront_access_logs.bucket_domain_name
    include_cookies = false
    prefix          = "maintenance/"
  }
  # CZID-356 (#356): CLOUDFRONT-scoped WAF (CKV_AWS_68 / CKV2_AWS_47). ARN, per the WAFv2 contract.
  web_acl_id = module.cloudfront_waf.web_acl_id

  aliases = [local.full_domain]

  origin {
    domain_name = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name

    # CZID-359 (#359): OAC replaces the s3_origin_config/OAI block (CKV2_AWS_46).
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_origin_access_control.id
  }

  custom_error_response {
    error_caching_min_ttl = 3600
    error_code            = 403
    response_code         = 503
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 3600
    error_code            = 404
    response_code         = 503
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name
    viewer_protocol_policy = "redirect-to-https"

    default_ttl = 86400
    max_ttl     = 31536000
    min_ttl     = 0

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  # Forward and cache assets requests to Rails web server.
  ordered_cache_behavior {
    path_pattern           = "/"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    default_ttl = 86400
    max_ttl     = 31536000
    min_ttl     = 0

    forwarded_values {
      # This is only necessary to set Vary: Origin header. See
      # https://stackoverflow.com/a/36585871 .
      headers = [
        "Origin",
      ]
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = module.assets-cert.arn
    ssl_support_method  = "sni-only"
    # CZID-61 (#61): enforce TLS >= 1.2 at the viewer edge (CKV_AWS_174). Was TLSv1.1_2016.
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "assets" {
  zone_id = local.zone_id
  name    = local.full_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_s3_bucket_versioning" "maintenance_bucket" {
  bucket = aws_s3_bucket.maintenance_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
