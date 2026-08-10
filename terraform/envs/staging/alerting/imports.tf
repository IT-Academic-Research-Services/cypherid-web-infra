# Adopt the 2026-08-06 click-ops resources into state so `terraform plan` reconciles them instead of
# recreating. Account 030998640247, us-west-2. Run a plan and review before apply (gated channel).
#
# The blocks below are keyed off the CANONICAL names this module uses. The ten resources whose live
# id is derived purely from a resource name (topic, roles, functions, event rules, alarms) import
# deterministically. The remaining five (2 inline role policies, 2 lambda permissions, 2 event
# targets, 1 subscription -- see the commented section) have ids that depend on the exact string
# typed at the CLI; verify each against the live resource before uncommenting, with the fetch
# command given inline.

import {
  to = module.slack_alerting.aws_sns_topic.alerts
  id = "arn:aws:sns:us-west-2:030998640247:seqtoid-staging-alerts"
}

import {
  to = module.slack_alerting.aws_iam_role.formatter
  id = "seqtoid-staging-alert-formatter"
}

import {
  to = module.slack_alerting.aws_lambda_function.formatter
  id = "seqtoid-staging-alert-formatter"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_rule.alarms
  id = "seqtoid-staging-alarm-formatter"
}

import {
  to = module.slack_alerting.aws_iam_role.canary
  id = "seqtoid-staging-web-canary"
}

import {
  to = module.slack_alerting.aws_lambda_function.canary
  id = "seqtoid-staging-web-canary"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_rule.canary_schedule
  id = "seqtoid-staging-web-canary-schedule"
}

import {
  to = module.slack_alerting.aws_cloudwatch_metric_alarm.web_down
  id = "seqtoid-staging-web-DOWN-no-healthy-targets"
}

import {
  to = module.slack_alerting.aws_cloudwatch_metric_alarm.canary_down
  id = "seqtoid-staging-web-canary-DOWN"
}

# The remaining five, filled from the live resources (fetched 2026-08-06). The module was aligned to
# these live ids (inline policy names, statement ids, target id "1") so every import is a no-op.

import {
  to = module.slack_alerting.aws_iam_role_policy.formatter
  id = "seqtoid-staging-alert-formatter:publish-and-log"
}

import {
  to = module.slack_alerting.aws_iam_role_policy.canary
  id = "seqtoid-staging-web-canary:putmetric-and-log"
}

import {
  to = module.slack_alerting.aws_lambda_permission.formatter_events
  id = "seqtoid-staging-alert-formatter/eventbridge-invoke"
}

import {
  to = module.slack_alerting.aws_lambda_permission.canary_schedule
  id = "seqtoid-staging-web-canary/schedule-invoke"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_target.formatter
  id = "seqtoid-staging-alarm-formatter/1"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_target.canary
  id = "seqtoid-staging-web-canary-schedule/1"
}

import {
  to = module.slack_alerting.aws_sns_topic_subscription.email
  id = "arn:aws:sns:us-west-2:030998640247:seqtoid-staging-alerts:6db5f695-c2c2-47c5-b753-b316decf25f5"
}
