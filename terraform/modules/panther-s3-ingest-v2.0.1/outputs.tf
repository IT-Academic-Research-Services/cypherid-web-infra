output "role" {
  value = {
    arn : aws_iam_role.log_processing_role.arn,
    name : aws_iam_role.log_processing_role.name,
  }
  description = "The role Panther uses to ingest the logs"
}

output "kms_id" {
  value       = (var.kms_key_arn == "") ? "<no kms configured>" : var.kms_key_arn
  description = "KMS Key ARN for the S3 Bucket"
}

output "topic_arn" {
  value       = aws_sns_topic.log_processing.arn
  description = "The SNS topic that's used to notify Panther when to pull new events"
}
