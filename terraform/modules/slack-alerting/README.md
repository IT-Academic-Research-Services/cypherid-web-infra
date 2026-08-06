# slack-alerting

Per-env proactive outage alerting to a Slack channel, via email-to-channel (SMP-1679).

Built because the target Slack is a **customer** workspace where we cannot create a webhook or
install an app -- so AWS Chatbot, a Slack app, and Grafana webhooks are all off the table. The only
channel we have is the channel's **email-to-channel address**, and Slack's email integration
**silently drops** raw CloudWatch->SNS alarm emails (a JSON wall). This module works around that: a
small Lambda reformats each alarm into a short, plain-text, Unicode-bolded message and publishes it
to SNS, whose email subscription is the channel address.

## What it creates

```
CloudWatch alarm (no SNS action)
      |  state change
      v
EventBridge rule  (alarmName prefix "<name_prefix>-")
      |
      v
Lambda <name_prefix>-alert-formatter  --publish-->  SNS <name_prefix>-alerts  --email-->  Slack channel

Scheduled EventBridge rule --> Lambda <name_prefix>-web-canary --PutMetricData--> SeqtoidSynthetics/SyntheticUp
```

Two alarms ship by default, both routed through the formatter:

- **`<name_prefix>-web-DOWN-no-healthy-targets`** -- sum of ALB `HealthyHostCount` across the
  blue+green target groups `< 1` for 3 min. Catches the pods-all-unhealthy 503 (the 2026-08-06
  env-staging outage signature). Fires with zero user traffic (ALB health-checks continuously).
- **`<name_prefix>-web-canary-DOWN`** -- synthetic canary can't `GET` the public URL (2xx/3xx) for
  3 min. Catches the layers *above* the pods: DNS, TLS cert, CloudFront/ALB routing, WAF, app status.

The EventBridge rule matches by name prefix, so **any** future `<name_prefix>-*` alarm (5xx rate,
RDS, latency, ...) reaches Slack with no extra wiring. You can also feed the `service-monitoring`
stack's `alarm_actions_sns_topic_arn` this module's `sns_topic_arn` output to unify delivery.

## Usage

```hcl
module "slack_alerting" {
  source = "../../../modules/slack-alerting"

  name_prefix               = "seqtoid-staging"
  env_label                 = "env-staging"
  tags                      = var.tags
  alert_email               = var.alert_email          # the Slack channel email-to-channel address
  check_url                 = "https://env-staging.seqtoid.org/"
  alb_arn_suffix            = "app/k8s-seqtoids-czidstag-be0e6a7699/286a703409c24c3e"
  target_group_arn_suffixes = [
    "targetgroup/3dddf2e904/3b9011292adc4a74",
    "targetgroup/80b42cc6f7/c1e58a05bd96b37b",
  ]
}
```

## One-time manual step

SNS cannot auto-confirm an email endpoint. On first apply a confirmation email lands **in the Slack
channel**; click **Confirm** once per topic. Until then the subscription shows
`pending_confirmation` (TF ignores that state).

## Adopting the existing CLI-built resources

Both dev and env-staging were first built by hand (click-ops, 2026-08-06). The per-env stacks under
`envs/<env>/alerting/` carry `import` blocks so `terraform plan` **adopts** the live resources
instead of recreating them. Expect the first plan to show small in-place updates (default_tags,
Lambda repackage) as the click-ops resources are reconciled to this SSOT -- that reconciliation is
the point. Review the plan before apply; apply runs through the normal gated TF channel.
