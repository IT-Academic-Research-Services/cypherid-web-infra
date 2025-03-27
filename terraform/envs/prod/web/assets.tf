locals {
  subdomain     = "assets"
  domain        = "${var.env}.idseq.net"
  full_domain   = "${local.subdomain}.${local.domain}"
  origin_domain = local.domain

  aliases = {
    "www.${local.full_domain}" = local.zone_id
  }
}

module "assets-cert" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.41.0"

  cert_domain_name               = local.full_domain
  aws_route53_zone_id            = local.zone_id
  cert_subject_alternative_names = local.aliases
  tags                           = var.tags

  # cloudfront requires us-east-1 acm certs
  providers = {
    aws = aws.us-east-1
  }
}

resource "aws_cloudfront_distribution" "distribution" {

  enabled = true
  comment = "Caches Rails web server static assets in Amazon's edge servers"

  aliases = [local.full_domain]

  # Rails web server
  origin {
    domain_name = local.origin_domain
    origin_id   = local.origin_domain

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
    target_origin_id       = local.origin_domain
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
    target_origin_id       = local.origin_domain
    viewer_protocol_policy = "redirect-to-https"
    # Time-to-live is set to 1 year. Rails puts a hash in the filename of
    # static assets, so changes to assets will result in new files, which
    # clients will then download from the origin.
    default_ttl = 31536000 # 1 year

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
    acm_certificate_arn      = module.assets-cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    project   = var.project
    env       = var.env
    service   = var.component
    owner     = var.owner
    managedBy = "terraform"
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
