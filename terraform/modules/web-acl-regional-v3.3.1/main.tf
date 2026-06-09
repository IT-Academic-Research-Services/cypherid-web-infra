locals {
  # determine waf's name: if empty, then use the shared-infra format
  web_acl_name = (var.name == "") ? "${var.tags.project}-${var.tags.env}-${var.tags.service}" : var.name

  # Create first set of rule_groups if defined:
  custom_rule_groups = {
    for index, rule_group in var.rule_groups :
    rule_group.arn => {
      "arn" : rule_group.arn,
      "name" : rule_group.name,
      "priority" : index + 1,
    }
  }

  # Define Priorities for the WebACL to track
  many_requests_priority           = length(var.rule_groups) + 2
  core_ruleset_priority            = local.many_requests_priority + 1
  bad_inputs_priority              = local.core_ruleset_priority + 1
  sql_ruleset_priority             = local.bad_inputs_priority + 1
  body_size_limit_ruleset_priority = local.sql_ruleset_priority + 1

  many_requests_rulename = "reaches-1000-per-5-min"
  core_ruleset_rulename  = "aws-common-rule-set"
  bad_inputs_rulename    = "aws-known-bad-inputs"
  sql_ruleset_rulename   = "aws-sql-rule-set"
}


resource "aws_wafv2_web_acl" "main" {
  name        = local.web_acl_name
  description = "Regional WAF for ${local.web_acl_name}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  #   Put some variable-defined priorities as first priority
  dynamic "rule" {
    for_each = local.custom_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        rule_group_reference_statement {
          arn = rule.value.arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${rule.value.name}-metrics"
        sampled_requests_enabled   = true
      }
    }
  }

  # Limit requests per 5 minutes
  rule {
    name     = local.many_requests_rulename
    priority = local.many_requests_priority

    action {
      count {}
    }

    statement {
      rate_based_statement {
        limit              = var.requests_per_5_min
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.many_requests_rulename
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = local.core_ruleset_rulename
    priority = local.core_ruleset_priority

    # If count_only is true, override to count, else don't override
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
        version     = var.aws_rulegroup_versions.CommonRuleSet
        # Count Exceptions
        dynamic "rule_action_override" {
          for_each = toset(var.czi_baseline_count_rules.CommonRuleSet)
          content {
            action_to_use {
              count {}
            }
            name = rule_action_override.key
          }
        }
        rule_action_override {
          # We have our own rule below with a different size
          name = "SizeRestrictions_BODY"
          action_to_use {
            allow {}
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


  rule {
    name     = local.bad_inputs_rulename
    priority = local.bad_inputs_priority

    # If enable_count_only is true, override to count, else don't override
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
        version     = var.aws_rulegroup_versions.KnownBadInputsRuleSet
        # Count Exceptions
        dynamic "rule_action_override" {
          for_each = toset(var.czi_baseline_count_rules.KnownBadInputsRuleSet)
          content {
            action_to_use {
              count {}
            }
            name = rule_action_override.key
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

  rule {
    name     = local.sql_ruleset_rulename
    priority = local.sql_ruleset_priority

    # If enable_count_only is true, override to count, else don't override
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
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
        version     = var.aws_rulegroup_versions.SQLiRuleSet
        # Count Exceptions
        dynamic "rule_action_override" {
          for_each = toset(var.czi_baseline_count_rules.SQLiRuleSet)
          content {
            action_to_use {
              count {}
            }
            name = rule_action_override.key
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = local.sql_ruleset_rulename
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "BodySizeLimitRuleSet"
    priority = local.body_size_limit_ruleset_priority
    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {}
        }
        comparison_operator = "GT" # Greater than
        size                = var.max_body_size
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "body-size-limit-rule-set"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = local.web_acl_name
    sampled_requests_enabled   = false
  }

  tags = var.tags
}
