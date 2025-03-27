locals {
  subdomain     = var.env
  domain        = "idseq.net"
  full_domain   = "${local.subdomain}.${local.domain}"
  origin_domain = "${var.env}.${local.domain}"
  origin_id     = "S3-public.idseq.net"

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

resource "aws_s3_bucket" "redirect_bucket" {
  bucket = "public.idseq.net-redirect"
  acl    = "public-read"

  website {
    redirect_all_requests_to = "http://public.czid.org"
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled = true
  comment = "Redirects from public.idseq.net to public.czid.org"

  aliases = [local.full_domain, "www.${local.full_domain}"]

  is_ipv6_enabled = true
  price_class     = "PriceClass_All"

  origin {
    domain_name = aws_s3_bucket.redirect_bucket.website_endpoint
    origin_id   = "S3-Website-${aws_s3_bucket.redirect_bucket.website_endpoint}"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1",
        "TLSv1.1",
        "TLSv1.2",
      ]
    }
  }

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", ]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id       = "S3-Website-${aws_s3_bucket.redirect_bucket.website_endpoint}"
    viewer_protocol_policy = "allow-all"

    default_ttl = 86400
    max_ttl     = 31536000

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = module.assets-cert.arn
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.1_2016"
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

resource "aws_route53_record" "ipv4" {
  zone_id = local.zone_id
  name    = local.full_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
