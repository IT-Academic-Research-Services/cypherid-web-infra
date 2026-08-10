# Adopt the 2026-08-06 click-ops resources into state. Account 491013321714, us-west-2.
# See envs/staging/alerting/imports.tf for the full rationale; this is the dev mirror.

import {
  to = module.slack_alerting.aws_sns_topic.alerts
  id = "arn:aws:sns:us-west-2:491013321714:seqtoid-dev-alerts"
}

import {
  to = module.slack_alerting.aws_iam_role.formatter
  id = "seqtoid-dev-alert-formatter"
}

import {
  to = module.slack_alerting.aws_lambda_function.formatter
  id = "seqtoid-dev-alert-formatter"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_rule.alarms
  id = "seqtoid-dev-alarm-formatter"
}

import {
  to = module.slack_alerting.aws_iam_role.canary
  id = "seqtoid-dev-web-canary"
}

import {
  to = module.slack_alerting.aws_lambda_function.canary
  id = "seqtoid-dev-web-canary"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_rule.canary_schedule
  id = "seqtoid-dev-web-canary-schedule"
}

import {
  to = module.slack_alerting.aws_cloudwatch_metric_alarm.web_down
  id = "seqtoid-dev-web-DOWN-no-healthy-targets"
}

import {
  to = module.slack_alerting.aws_cloudwatch_metric_alarm.canary_down
  id = "seqtoid-dev-web-canary-DOWN"
}

# The remaining five, filled from the live resources (fetched 2026-08-06). Same live ids as staging.

import {
  to = module.slack_alerting.aws_iam_role_policy.formatter
  id = "seqtoid-dev-alert-formatter:publish-and-log"
}

import {
  to = module.slack_alerting.aws_iam_role_policy.canary
  id = "seqtoid-dev-web-canary:putmetric-and-log"
}

import {
  to = module.slack_alerting.aws_lambda_permission.formatter_events
  id = "seqtoid-dev-alert-formatter/eventbridge-invoke"
}

import {
  to = module.slack_alerting.aws_lambda_permission.canary_schedule
  id = "seqtoid-dev-web-canary/schedule-invoke"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_target.formatter
  id = "seqtoid-dev-alarm-formatter/1"
}

import {
  to = module.slack_alerting.aws_cloudwatch_event_target.canary
  id = "seqtoid-dev-web-canary-schedule/1"
}

import {
  to = module.slack_alerting.aws_sns_topic_subscription.email
  id = "arn:aws:sns:us-west-2:491013321714:seqtoid-dev-alerts:79387ef4-63d4-4756-968b-c4ba18daaf98"
}
