locals {
  rule_group_name = "${var.tags.project}-${var.tags.env}-${var.tags.service}-geoblocking"
}

resource "aws_wafv2_rule_group" "geo_restriction" {
  name        = local.rule_group_name
  description = "WAF rule group to block countries in the geoblocking list."
  scope       = var.scope
  capacity    = 10

  rule {
    name     = "block-geoblocked-countries"
    priority = 1
    action {
      block {}
    }
    statement {
      geo_match_statement {
        country_codes = ["IR", "CU", "KP", "UA"]
      }
    }
    visibility_config {
      sampled_requests_enabled   = var.enable_visibility
      cloudwatch_metrics_enabled = var.enable_visibility
      metric_name                = "block-geoblocked-countries"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_visibility
    metric_name                = local.rule_group_name
    sampled_requests_enabled   = var.enable_visibility
  }
}
