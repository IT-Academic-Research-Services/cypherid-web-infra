locals {
  czid_subdomain     = var.env
  czid_domain        = "czid.org"
  czid_full_domain   = "${local.czid_subdomain}.${local.czid_domain}"
  czid_origin_domain = "${var.env}.${local.czid_domain}"
  czid_origin_id     = "S3-public.${local.czid_domain}"

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

resource "aws_cloudfront_distribution" "czid-distribution" {
  enabled = true
  comment = "Serves files from s3://public.czid.org See also: https://github.com/chanzuckerberg/public.idseq.net"

  aliases = [local.czid_full_domain, "www.${local.czid_full_domain}"]

  default_root_object = "index.html"

  origin {
    domain_name = "public.czid.org.s3.amazonaws.com"
    origin_id   = local.czid_origin_id
  }

  # By default, forward without caching requests to Rails web server. In future,
  # we may want to cache some of these, and forward others to an s3 bucket.
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id       = local.czid_origin_id
    viewer_protocol_policy = "redirect-to-https"

    default_ttl = 3600
    max_ttl     = 86400

    forwarded_values {
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
    project   = var.project
    env       = var.env
    service   = var.component
    owner     = var.owner
    managedBy = "terraform"
  }
}

resource "aws_route53_record" "czid-ipv4" {
  zone_id = local.czid_zone_id
  name    = local.czid_full_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.czid-distribution.domain_name
    zone_id                = aws_cloudfront_distribution.czid-distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "czid-ipv4-www" {
  zone_id = local.czid_zone_id
  name    = "www.${local.czid_full_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.czid-distribution.domain_name
    zone_id                = aws_cloudfront_distribution.czid-distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
