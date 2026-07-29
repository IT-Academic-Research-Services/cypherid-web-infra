locals {
  name = "seqtoid-${var.env}-web-allowlist"
}

# UCSF egress allowlist. IPv4 + IPv6 IP sets. Empty addresses = matches nothing = fail-closed (default
# BLOCK blocks everyone until the CIDRs are filled in).
resource "aws_wafv2_ip_set" "ucsf_v4" {
  name               = "${local.name}-v4"
  description        = "UCSF egress IPv4 CIDRs allowed to reach prod.seqtoid.org"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.ucsf_allowlist_cidrs
}

resource "aws_wafv2_ip_set" "ucsf_v6" {
  name               = "${local.name}-v6"
  description        = "UCSF egress IPv6 CIDRs allowed to reach prod.seqtoid.org"
  scope              = "REGIONAL"
  ip_address_version = "IPV6"
  addresses          = var.ucsf_allowlist_ipv6_cidrs
}

# DENY-BY-DEFAULT Web ACL: default action BLOCK. A request is allowed only if it (1) passes the AWS
# Common Rule Set (defense-in-depth, blocks known-bad even from UCSF) and (2) originates from a UCSF
# allowlisted IP. Everything else falls through to the default block.
resource "aws_wafv2_web_acl" "prod_preview" {
  name        = local.name
  description = "Deny-by-default edge for prod.seqtoid.org: UCSF egress allowlist only (locked-down pre-prod)."
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  # 1) AWS managed Common Rule Set -- inspects ALL traffic (incl. allowlisted UCSF) and blocks known-bad
  #    patterns. Runs before the allow so a malicious request from a UCSF IP is still blocked.
  rule {
    name     = "aws-common-rule-set"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rule-set"
    }
  }

  # 2) The ONLY allow path: source IP in the UCSF allowlist (v4 or v6). No match here -> default BLOCK.
  rule {
    name     = "ucsf-allowlist"
    priority = 2
    action {
      allow {}
    }
    statement {
      or_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.ucsf_v4.arn
          }
        }
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.ucsf_v6.arn
          }
        }
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "ucsf-allowlist"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = local.name
  }
}

output "web_acl_arn" {
  description = "ARN of the deny-by-default Web ACL -- set as alb.ingress.kubernetes.io/wafv2-acl-arn in values/seqtoid-web/prod-preview.yaml."
  value       = aws_wafv2_web_acl.prod_preview.arn
}
