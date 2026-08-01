locals {
  assets_fqdn     = "assets.${local.env_fqdn}"
  www_assets_fqdn = "www.${local.assets_fqdn}"

  assets_aliases = {
    (local.www_assets_fqdn) = local.zone_id
  }
}

module "assets-cert" {
  source = "../../../modules/aws-acm-certificate-v0.104.2" # cztack v0.104.2

  cert_domain_name               = local.assets_fqdn
  aws_route53_zone_id            = local.zone_id
  cert_subject_alternative_names = local.assets_aliases
  tags                           = var.tags # TODO: var.tags is deprecated

  # cloudfront requires us-east-1 acm certs
  providers = {
    aws = aws.us-east-1
  }
}

resource "aws_cloudfront_distribution" "distribution" {

  enabled = true
  comment = "Caches Rails web server static assets in Amazon's edge servers"

  # CZID-61 (#61): CloudFront standard access logging to a private S3 bucket (CKV_AWS_86).
  logging_config {
    bucket          = module.cloudfront_access_logs.bucket_domain_name
    include_cookies = false
    prefix          = "assets/"
  }
  # CZID-356 (#356): CLOUDFRONT-scoped WAF (CKV_AWS_68 / CKV2_AWS_47). ARN, per the WAFv2 contract.
  web_acl_id = module.cloudfront_waf.web_acl_id

  aliases = [local.assets_fqdn]

  # Rails web server
  origin {
    domain_name = local.env_fqdn
    origin_id   = local.env_fqdn

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "https-only"
      # SMP-1627: raise the origin TLS floor to 1.2 (parity with prod).
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  # By default, forward without caching requests to Rails web server. In future,
  # we may want to cache some of these, and forward others to an s3 bucket.
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.env_fqdn
    viewer_protocol_policy = "redirect-to-https"
    # SMP-1627: attach the security-headers response policy (parity with prod; the
    # policy was created in headers.tf but left unwired in dev).
    response_headers_policy_id = module.security_headers.policy_id

    default_ttl = 0
    max_ttl     = 0

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  # Forward and cache assets requests to Rails web server.
  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.env_fqdn
    viewer_protocol_policy = "redirect-to-https"
    # SMP-1627: attach the security-headers response policy (parity with prod).
    response_headers_policy_id = module.security_headers.policy_id
    # Time-to-live is set to 1 year. Rails puts a hash in the filename of
    # static assets, so changes to assets will result in new files, which
    # clients will then download from the origin.
    default_ttl = 31536000 # 1 year
    max_ttl     = 31536000 # 1 year

    forwarded_values {
      # This is only necessary to set Vary: Origin header. See
      # https://stackoverflow.com/a/36585871 .
      headers = [
        "Origin",
      ]
      query_string = true

      cookies {
        forward = "all"
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
  name    = local.assets_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
