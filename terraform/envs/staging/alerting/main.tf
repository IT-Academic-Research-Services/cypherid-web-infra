# SMP-1679 -- proactive outage alerting to Tom's Slack channel for env-staging.
# Consumes the SSOT terraform/modules/slack-alerting. See that module's README for the why.
#
# The ALB + target-group ARN suffixes are the seqtoid-staging web ALB (k8s-seqtoids-czidstag) and
# its blue/green target groups. If the ALB is ever recreated these change -- read them from the
# web/eks stack's remote state instead of hard-coding once that output is exposed.

module "slack_alerting" {
  source = "../../../modules/slack-alerting"

  name_prefix = "seqtoid-staging"
  env_label   = "env-staging"
  tags        = var.tags
  alert_email = var.alert_email
  check_url   = "https://env-staging.seqtoid.org/"

  alb_arn_suffix = "app/k8s-seqtoids-czidstag-be0e6a7699/286a703409c24c3e"
  target_group_arn_suffixes = [
    "targetgroup/3dddf2e904/3b9011292adc4a74",
    "targetgroup/80b42cc6f7/c1e58a05bd96b37b",
  ]
}
