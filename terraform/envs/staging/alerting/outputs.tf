output "sns_topic_arn" {
  value = module.slack_alerting.sns_topic_arn
}

output "alarm_names" {
  value = module.slack_alerting.alarm_names
}
