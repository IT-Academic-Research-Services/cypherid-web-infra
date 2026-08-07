output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "The alerts topic. Also usable as alarm_actions_sns_topic_arn for the service-monitoring stack so those alarms flow to the same channel."
}

output "formatter_function_name" {
  value = aws_lambda_function.formatter.function_name
}

output "canary_function_name" {
  value = aws_lambda_function.canary.function_name
}

output "alarm_names" {
  value = [
    aws_cloudwatch_metric_alarm.web_down.alarm_name,
    aws_cloudwatch_metric_alarm.canary_down.alarm_name,
  ]
}
