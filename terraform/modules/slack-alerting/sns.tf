# SNS topic the formatter publishes to; its email subscription is the Slack channel address.
# The subscription requires a one-time manual Confirm click in the Slack channel (SNS cannot
# auto-confirm an email endpoint) -- so `confirmation_timeout_in_minutes` is generous and TF
# will show the subscription as "pending confirmation" until Tom clicks it.
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  tags = var.tags

  # SSE at rest with the AWS-managed SNS key (CKV_AWS_26). The formatter role is granted
  # kms:GenerateDataKey*/Decrypt (see formatter.tf) so it can still publish to the encrypted topic.
  kms_master_key_id = "alias/aws/sns"
}

# The endpoint is confirmed out-of-band in Slack (a click in the channel); SNS reports the sub as
# pending_confirmation until then. That attribute is provider-computed, so it needs no ignore_changes.
resource "aws_sns_topic_subscription" "email" {
  topic_arn                       = aws_sns_topic.alerts.arn
  protocol                        = "email"
  endpoint                        = var.alert_email
  confirmation_timeout_in_minutes = 30
}
