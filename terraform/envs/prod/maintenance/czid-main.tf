locals {
  czid_subdomain   = "maintenance"
  czid_domain      = "czid.org"
  czid_full_domain = "${local.czid_subdomain}.${local.czid_domain}"
  czid_zone_id     = data.terraform_remote_state.idseq-prod.outputs.czid_org_zone_id

  czid_aliases = {
    "www.${local.czid_full_domain}" = local.czid_zone_id
  }
}

resource "aws_s3_bucket" "maintenance_bucket" {
  bucket = local.czid_full_domain
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}


data "aws_iam_policy_document" "czid_s3_iam_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.maintenance_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.czid_origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "czid_s3_bucket_policy" {
  bucket = aws_s3_bucket.maintenance_bucket.id
  policy = data.aws_iam_policy_document.czid_s3_iam_policy.json
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

resource "aws_cloudfront_origin_access_identity" "czid_origin_access_identity" {
  comment = "OAI for maintenance cloudfront distribution"
}


resource "aws_cloudfront_distribution" "czid_distribution" {

  enabled             = true
  default_root_object = "index.html"
  comment             = "Serves ${var.env} czid maintenance page from S3 bucket"

  aliases = [local.czid_full_domain]

  origin {
    domain_name = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.czid_origin_access_identity.cloudfront_access_identity_path
    }
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

resource "aws_route53_record" "czid-assets" {
  zone_id = local.czid_zone_id
  name    = local.czid_full_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.czid_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.czid_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
