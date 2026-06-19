locals {
  zone_id            = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id
  env_fqdn           = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  www_env_fqdn       = "www.${local.env_fqdn}"
  component_fqdn     = "${var.component}.${local.env_fqdn}"
  www_component_fqdn = "www.${local.component_fqdn}"

  # aliases = {
  #   "www.${local.full_domain}" = local.zone_id
  # }

  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
  }
}

resource "aws_s3_bucket" "maintenance_bucket" {
  bucket        = local.component_fqdn
  acl           = "private"
  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

data "aws_iam_policy_document" "s3_iam_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.maintenance_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.maintenance_bucket.id
  policy = data.aws_iam_policy_document.s3_iam_policy.json
}

# module "assets-cert" {
#   source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.104.2"
#
#   cert_domain_name               = local.full_domain
#   aws_route53_zone_id            = local.zone_id
#   cert_subject_alternative_names = local.aliases
#   tags                           = var.tags
#
#   # cloudfront requires us-east-1 acm certs
#   providers = {
#     aws = aws.us-east-1
#   }
# }

module "env-cert" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.104.2"

  cert_domain_name    = local.env_fqdn
  aws_route53_zone_id = local.zone_id
  tags                = var.tags # TODO: var.tags is deprecated

  cert_subject_alternative_names = {
    (local.env_fqdn)           = local.zone_id
    (local.www_env_fqdn)       = local.zone_id
    (local.component_fqdn)     = local.zone_id
    (local.www_component_fqdn) = local.zone_id
  }
  providers = {
    aws = aws.us-east-1
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "OAI for maintenance cloudfront distribution"
}

resource "aws_cloudfront_distribution" "distribution" {

  enabled             = true
  default_root_object = "index.html"
  comment             = "Serves ${var.env} maintenance page from S3 bucket"

  aliases = [
    local.env_fqdn,
    local.www_env_fqdn,
    local.component_fqdn,
    local.www_component_fqdn,
  ]

  origin {
    domain_name = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.maintenance_bucket.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
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

    min_ttl     = 0
    default_ttl = 3600  # 86400
    max_ttl     = 86400 # 31536000

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

    default_ttl = 31536000 # 1 year; TODO: This seems wrong! Should probably be 86400
    # max_ttl     = 31536000
    # min_ttl     = 0

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
    acm_certificate_arn      = module.env-cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.1_2016"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "maintenance_env_redirect" {
  zone_id = local.zone_id
  name    = local.component_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_maintenance_env_redirect" {
  zone_id = local.zone_id
  name    = local.www_component_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "env_redirect" {
  zone_id = local.zone_id
  name    = local.env_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www_env_redirect" {
  zone_id = local.zone_id
  name    = local.www_env_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_s3_object" "landing_page_static" {
  for_each = fileset("${path.module}/dist", "**/*")

  bucket       = aws_s3_bucket.maintenance_bucket.id
  key          = each.value
  source       = "${path.module}/dist/${each.value}"
  etag         = filemd5("${path.module}/dist/${each.value}")
  content_type = lookup(local.mime_types, regex("[^.]+$", each.value), "application/octet-stream")
}

resource "aws_s3_object" "landing_page_templates" {
  for_each = fileset("${path.module}/templates", "**/*")

  bucket       = aws_s3_bucket.maintenance_bucket.id
  key          = each.value
  content_type = lookup(local.mime_types, regex("[^.]+$", each.value), "application/octet-stream")

  content = templatefile("${path.module}/templates/${each.value}", {
    REPLACE_WITH_API_GATEWAY_ENDPOINT = "${aws_api_gateway_stage.prod.invoke_url}${aws_api_gateway_resource.signup.path}"
  })

  etag = md5(templatefile("${path.module}/templates/${each.value}", {
    REPLACE_WITH_API_GATEWAY_ENDPOINT = "${aws_api_gateway_stage.prod.invoke_url}${aws_api_gateway_resource.signup.path}"
  }))
}
