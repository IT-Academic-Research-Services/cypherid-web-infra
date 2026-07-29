# CZID-356 (#356): CLOUDFRONT-scoped WAFv2 Web ACL for the platform's CloudFront distributions.
#
# WHY A SEPARATE MODULE FROM web-acl-regional-v3.3.1:
# CloudFront requires a Web ACL with scope = CLOUDFRONT that lives in us-east-1 (a GLOBAL ACL). That is
# a DISTINCT resource from the REGIONAL ALB ACL created by web-acl-regional-v3.3.1 / envs/*/web-waf
# (the geo/anonymizer/export-control stack, #280/#281/#282) — a REGIONAL ACL ARN cannot be attached to
# a CloudFront distribution (scope mismatch = apply error), so this is not a reuse of that ACL.
#
# PROVIDER: the caller MUST pass an aws provider aliased to us-east-1 (providers = { aws = aws.us-east-1 }).
# The web stacks already declare that alias for their CloudFront ACM certs, so no new provider is needed.
#
# SCOPE OF THIS MODULE: attach a WAF with AWS-managed baseline rule groups (CommonRuleSet +
# KnownBadInputs at minimum) so the public edge has L7 filtering (CKV_AWS_68 / CKV2_AWS_47). It is
# intentionally minimal — the export-control geo/anonymizer rules live on the REGIONAL ALB ACL and are
# NOT duplicated here.

locals {
  web_acl_name = (var.name == "") ? "${var.tags.project}-${var.tags.env}-${var.tags.service}-cloudfront" : var.name

  core_ruleset_priority = 1
  bad_inputs_priority   = 2

  core_ruleset_rulename = "aws-common-rule-set"
  bad_inputs_rulename   = "aws-known-bad-inputs"
}

resource "aws_wafv2_web_acl" "cloudfront" {
  # checkov:skip=CKV_AWS_192:Log4Shell (CVE-2021-44228) is mitigated by the AWSManagedRulesKnownBadInputsRuleSet rule group configured below; checkov 3.3.x throws a TypeError evaluating this check on the rendered dynamic rule set (upstream bug), so it is skipped rather than left to crash. Mirrors the same skip on the regional ACL (web-acl-regional-v3.3.1).
  name        = local.web_acl_name
  description = "CLOUDFRONT-scoped WAF for ${local.web_acl_name} - baseline AWS managed rules"
  scope       = "CLOUDFRONT"

  # A public edge cannot default-deny all traffic; enforcement is by the managed rule BLOCK actions below.
  default_action {
    allow {}
  }

  # AWSManagedRulesCommonRuleSet — OWASP-style baseline (bad bots, SSRF, LFI/RFI, XSS, size restrictions).
  rule {
    name     = local.core_ruleset_rulename
    priority = local.core_ruleset_priority

    # count_only canary: run the whole rule group in COUNT during the observability bake, then flip to
    # enforce (none {} = use the group's own block actions). Behaviour-sensitive — this can block real
    # traffic, so envs bake in count first (see PR body / #356).
    dynamic "override_action" {
      for_each = (var.count_only == true) ? [1] : []
      content {
        count {}
      }
    }
    dynamic "override_action" {
      for_each = (var.count_only == false) ? [1] : []
      content {
        none {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Per-sub-rule COUNT exceptions for false-positive tuning (e.g. SizeRestrictions_BODY on large
        # asset uploads). Empty (default) = every sub-rule blocks.
        dynamic "rule_action_override" {
          for_each = toset(var.common_ruleset_count_rules)
          content {
            name = rule_action_override.key
            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.core_ruleset_rulename
      sampled_requests_enabled   = true
    }
  }

  # AWSManagedRulesKnownBadInputsRuleSet — blocks request patterns known to be invalid/exploitative
  # (incl. Log4Shell / CVE-2021-44228 — see the CKV_AWS_192 skip above).
  rule {
    name     = local.bad_inputs_rulename
    priority = local.bad_inputs_priority

    dynamic "override_action" {
      for_each = (var.count_only == true) ? [1] : []
      content {
        count {}
      }
    }
    dynamic "override_action" {
      for_each = (var.count_only == false) ? [1] : []
      content {
        none {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"

        dynamic "rule_action_override" {
          for_each = toset(var.known_bad_inputs_count_rules)
          content {
            name = rule_action_override.key
            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.bad_inputs_rulename
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.web_acl_name
    sampled_requests_enabled   = true
  }

  tags = var.tags
}
