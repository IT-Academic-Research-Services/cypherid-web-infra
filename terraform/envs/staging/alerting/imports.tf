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

# --- Verify-then-uncomment. Live ids depend on the CLI-typed names; fetch, confirm they match the
# --- module's canonical names (rename in the module if not), then uncomment.
#
# Inline role policies -- id "<role>:<inline-policy-name>". Confirm the inline policy name:
#   aws iam list-role-policies --role-name seqtoid-staging-alert-formatter --profile idseq-staging
#   aws iam list-role-policies --role-name seqtoid-staging-web-canary       --profile idseq-staging
# import { to = module.slack_alerting.aws_iam_role_policy.formatter
#   id = "seqtoid-staging-alert-formatter:publish-and-log" }
# import { to = module.slack_alerting.aws_iam_role_policy.canary
#   id = "seqtoid-staging-web-canary:putmetric-and-log" }
#
# Lambda permissions -- id "<function>/<statement-id>". Confirm the statement id:
#   aws lambda get-policy --function-name seqtoid-staging-alert-formatter --profile idseq-staging --query Policy --output text | jq '.Statement[].Sid'
#   aws lambda get-policy --function-name seqtoid-staging-web-canary      --profile idseq-staging --query Policy --output text | jq '.Statement[].Sid'
# import { to = module.slack_alerting.aws_lambda_permission.formatter_events
#   id = "seqtoid-staging-alert-formatter/AllowEventBridgeInvoke" }
# import { to = module.slack_alerting.aws_lambda_permission.canary_schedule
#   id = "seqtoid-staging-web-canary/AllowScheduleInvoke" }
#
# Event targets -- id "<rule>/<target-id>". A WRONG target-id leaves the CLI target in place AND
# adds a second one (double Slack posts) -- so confirm, or delete the CLI target and let TF create:
#   aws events list-targets-by-rule --rule seqtoid-staging-alarm-formatter        --profile idseq-staging --query 'Targets[].Id'
#   aws events list-targets-by-rule --rule seqtoid-staging-web-canary-schedule    --profile idseq-staging --query 'Targets[].Id'
# import { to = module.slack_alerting.aws_cloudwatch_event_target.formatter
#   id = "seqtoid-staging-alarm-formatter/formatter" }
# import { to = module.slack_alerting.aws_cloudwatch_event_target.canary
#   id = "seqtoid-staging-web-canary-schedule/canary" }
#
# SNS email subscription -- id is the full subscription ARN (topic-arn:uuid). Fetch:
#   aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:us-west-2:030998640247:seqtoid-staging-alerts --profile idseq-staging --query 'Subscriptions[?Protocol==`email`].SubscriptionArn'
# import { to = module.slack_alerting.aws_sns_topic_subscription.email
#   id = "arn:aws:sns:us-west-2:030998640247:seqtoid-staging-alerts:<uuid>" }
