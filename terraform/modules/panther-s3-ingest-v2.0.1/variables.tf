# Copyright (C) 2022 Panther Labs, Inc.
#
# The Panther SaaS is licensed under the terms of the Panther Enterprise Subscription
# Agreement available at https://panther.com/enterprise-subscription-agreement/.
# All intellectual property rights in and to the Panther SaaS, including any and all
# rights to access the Panther SaaS, are governed by the Panther Enterprise Subscription Agreement.

variable "role_suffix" {
  type        = string
  description = <<-EOT
  A unique identifier that will be used as the IAM role suffix. 
  The role will be named `PantherLogProcessingRole-<var.role_suffix>`
  EOT
}

variable "s3_bucket_name" {
  type        = string
  description = "The S3 Bucket to onboard to Panther for log ingestion (just the name)."
}

variable "tags" {
  description = "Tags to apply to the Panther Ingestion Role"
  type        = map(string)
}

variable "managed_bucket_notifications_enabled" {
  type        = bool
  description = "Allow Panther to configure bucket SNS notifications so it can be notified of new logs. [Context](https://docs.panther.com/data-onboarding/data-transports/s3#manual-iam-role-creation-additional-steps)"
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "The S3 Bucket's KMS Key ARN if it has one."
  default     = ""
}
