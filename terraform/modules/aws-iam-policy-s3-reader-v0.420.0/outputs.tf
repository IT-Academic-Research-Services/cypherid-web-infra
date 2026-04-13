output "policy" {
  value = {
    "arn" : aws_iam_policy.s3-bucket-reader.arn,
    "id" : aws_iam_policy.s3-bucket-reader.id,
    "policy_id" : aws_iam_policy.s3-bucket-reader.policy_id,
  }
}