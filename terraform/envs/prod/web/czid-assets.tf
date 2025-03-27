locals {
  czid_subdomain     = "assets"
  czid_domain        = "${var.env}.czid.org"
  czid_full_domain   = "${local.czid_subdomain}.${local.czid_domain}"
  czid_origin_domain = local.czid_domain

  czid_aliases = {
    "www.${local.czid_full_domain}" = local.czid_zone_id
  }
}

module "czid-assets-cert" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.41.0"

  cert_domain_name               = local.czid_full_domain
  aws_route53_zone_id            = local.czid_zone_id
  cert_subject_alternative_names = local.czid_aliases
  tags                           = var.tags

  # cloudfront requires us-east-1 acm certs
  providers = {
    aws = aws.us-east-1
  }
}

resource "aws_cloudfront_distribution" "czid-assets-distribution" {

  enabled = true
  comment = "Caches Rails web server static assets in Amazon's edge servers"

  aliases = [local.czid_full_domain]

  # Rails web server
  origin {
    domain_name = local.czid_origin_domain
    origin_id   = local.czid_origin_domain

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.1"]
    }
  }

  # By default, forward without caching requests to Rails web server. In future,
  # we may want to cache some of these, and forward others to an s3 bucket.
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.czid_origin_domain
    viewer_protocol_policy = "redirect-to-https"

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
    target_origin_id       = local.czid_origin_domain
    viewer_protocol_policy = "redirect-to-https"
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
    acm_certificate_arn      = module.czid-assets-cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    project   = var.project_v1
    env       = var.env
    service   = var.component
    owner     = var.owner
    managedBy = "terraform"
  }
}

resource "aws_route53_record" "czid-assets" {
  zone_id = local.czid_zone_id
  name    = local.czid_full_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.czid-assets-distribution.domain_name
    zone_id                = aws_cloudfront_distribution.czid-assets-distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
