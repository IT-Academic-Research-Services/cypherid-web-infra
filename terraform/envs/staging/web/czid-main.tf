locals {
  czid_zone_id = data.terraform_remote_state.idseq-dev.outputs.staging_czid_org_zone_id
}

module "czid-staging-cert" {
  source = "github.com/chanzuckerberg/cztack//aws-acm-certificate?ref=v0.41.0"

  cert_domain_name    = local.czid_origin_domain
  aws_route53_zone_id = local.czid_zone_id
  tags                = var.tags

  cert_subject_alternative_names = {
    "www.${local.czid_origin_domain}" = local.czid_zone_id
  }
}

module "czid-web-service" {
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/ecs-service-with-alb?ref=v0.421.0"

  service             = "web"
  project             = var.project_v1
  owner               = var.owner
  container_port      = 3000
  container_name      = "rails"
  env                 = var.env
  vpc_id              = data.terraform_remote_state.cloud-env.outputs.vpc_id
  cluster_id          = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn       = aws_iam_role.idseq-web.arn
  desired_count       = 2
  lb_subnets          = data.terraform_remote_state.cloud-env.outputs.public_subnets
  route53_zone_id     = local.czid_zone_id
  subdomain           = ""
  health_check_path   = "/health_check"
  acm_certificate_arn = module.czid-staging-cert.arn
  lb_egress_cidrs     = [data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block]
  access_logs_bucket  = data.terraform_remote_state.elb-access-logs.outputs.bucket_name
  # The AWS and module default is 60s. We decided to increase it after observing
  # multiple endpoints exceeding that in production under normal loads, including
  # bulk_upload_with_metadata and report_csv.
  lb_idle_timeout_seconds = 300
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

resource "aws_route53_record" "czid-www" {
  zone_id = local.czid_zone_id
  name    = "www.${local.czid_origin_domain}"
  type    = "A"

  alias {
    name                   = module.czid-web-service.alb_dns_name
    zone_id                = module.czid-web-service.alb_route53_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket" "redirect_bucket" {
  bucket = "staging.idseq.net"
  acl    = "public-read"

  website {
    redirect_all_requests_to = "http://staging.czid.org"
  }
}

resource "aws_cloudfront_distribution" "redirect_distribution" {
  aliases             = ["staging.idseq.net"]
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
    target_origin_id       = "S3-Website-${aws_s3_bucket.redirect_bucket.website_endpoint}"
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

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = module.staging_east.arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.1_2016"
    ssl_support_method             = "sni-only"
  }
}

resource "aws_route53_record" "redirect" {
  zone_id = local.zone_id
  name    = "staging.idseq.net."
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.redirect_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.redirect_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
