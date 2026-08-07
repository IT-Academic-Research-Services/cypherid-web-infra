# SMP-1679 -- proactive outage alerting to Tom's Slack channel for dev.
# Consumes the SSOT terraform/modules/slack-alerting. Mirror of the staging stack; differs only by
# account, URL, and ALB/target-group ARN suffixes (the seqtoid-dev web ALB, k8s-seqtoidd-cziddevs).

module "slack_alerting" {
  source = "../../../modules/slack-alerting"

  name_prefix = "seqtoid-dev"
  env_label   = "dev"
  tags        = var.tags
  alert_email = var.alert_email
  check_url   = "https://dev.seqtoid.org/"

  alb_arn_suffix = "app/k8s-seqtoidd-cziddevs-c4552c1c21/f5632d3be5837a88"
  target_group_arn_suffixes = [
    "targetgroup/3286544e31/c7c96f234c262314",
    "targetgroup/ba53e3e3d1/d798dcee489ec1bb",
  ]
}
