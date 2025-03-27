locals {
  czid_zone_id   = data.terraform_remote_state.idseq-prod.outputs.czid_org_zone_id
  czid_help_host = "help.czid.org"
}

resource "aws_s3_bucket" "czid_help_redirect_bucket" {
  bucket = local.czid_help_host
  acl    = "public-read"

  website {
    redirect_all_requests_to = "http://chanzuckerberg.zendesk.com"
  }
}

module "czid_help_cert" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.41.0"

  cert_domain_name    = local.czid_help_host
  aws_route53_zone_id = local.czid_zone_id

  cert_subject_alternative_names = {
    "www.${local.czid_help_host}" = local.czid_zone_id
  }

  tags = var.tags

  # cloudfront requires us-east-1 acm certs
  providers = {
    aws = aws.us-east-1
  }
}

resource "aws_cloudfront_distribution" "czid_help_s3_distribution" {
  aliases             = [local.czid_help_host]
  enabled             = true
  http_version        = "http2"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = true

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]
    compress               = false
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    smooth_streaming       = false
    target_origin_id       = "S3-Website-${aws_s3_bucket.czid_help_redirect_bucket.website_endpoint}"
    trusted_signers        = []
    viewer_protocol_policy = "allow-all"

    forwarded_values {
      headers                 = []
      query_string            = false
      query_string_cache_keys = []

      cookies {
        forward           = "none"
        whitelisted_names = []
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.czid_help_redirect_bucket.website_endpoint
    origin_id   = "S3-Website-${aws_s3_bucket.czid_help_redirect_bucket.website_endpoint}"

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

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = module.czid_help_cert.arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.1_2016"
    ssl_support_method             = "sni-only"
  }
}

resource "aws_route53_record" "czid_help_site" {
  zone_id = local.czid_zone_id
  name    = "${local.czid_help_host}."
  type    = "CNAME"
  ttl     = "300"
  records = [aws_cloudfront_distribution.czid_help_s3_distribution.domain_name]
}
