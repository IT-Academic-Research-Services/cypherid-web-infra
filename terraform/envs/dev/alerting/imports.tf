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

# --- Verify-then-uncomment (live ids depend on the CLI-typed names). Profile idseq-dev.
#
# Inline role policies -- "<role>:<inline-policy-name>":
#   aws iam list-role-policies --role-name seqtoid-dev-alert-formatter --profile idseq-dev
#   aws iam list-role-policies --role-name seqtoid-dev-web-canary       --profile idseq-dev
# import { to = module.slack_alerting.aws_iam_role_policy.formatter
#   id = "seqtoid-dev-alert-formatter:publish-and-log" }
# import { to = module.slack_alerting.aws_iam_role_policy.canary
#   id = "seqtoid-dev-web-canary:putmetric-and-log" }
#
# Lambda permissions -- "<function>/<statement-id>":
#   aws lambda get-policy --function-name seqtoid-dev-alert-formatter --profile idseq-dev --query Policy --output text | jq '.Statement[].Sid'
#   aws lambda get-policy --function-name seqtoid-dev-web-canary      --profile idseq-dev --query Policy --output text | jq '.Statement[].Sid'
# import { to = module.slack_alerting.aws_lambda_permission.formatter_events
#   id = "seqtoid-dev-alert-formatter/AllowEventBridgeInvoke" }
# import { to = module.slack_alerting.aws_lambda_permission.canary_schedule
#   id = "seqtoid-dev-web-canary/AllowScheduleInvoke" }
#
# Event targets -- "<rule>/<target-id>" (wrong id => duplicate target => double posts):
#   aws events list-targets-by-rule --rule seqtoid-dev-alarm-formatter     --profile idseq-dev --query 'Targets[].Id'
#   aws events list-targets-by-rule --rule seqtoid-dev-web-canary-schedule --profile idseq-dev --query 'Targets[].Id'
# import { to = module.slack_alerting.aws_cloudwatch_event_target.formatter
#   id = "seqtoid-dev-alarm-formatter/formatter" }
# import { to = module.slack_alerting.aws_cloudwatch_event_target.canary
#   id = "seqtoid-dev-web-canary-schedule/canary" }
#
# SNS email subscription -- full subscription ARN:
#   aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:us-west-2:491013321714:seqtoid-dev-alerts --profile idseq-dev --query 'Subscriptions[?Protocol==`email`].SubscriptionArn'
# import { to = module.slack_alerting.aws_sns_topic_subscription.email
#   id = "arn:aws:sns:us-west-2:491013321714:seqtoid-dev-alerts:<uuid>" }
