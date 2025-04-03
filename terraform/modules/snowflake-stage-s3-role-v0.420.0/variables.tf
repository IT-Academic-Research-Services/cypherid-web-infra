variable "project" {
  type        = string
  description = "Project for tagging and naming. See [doc](../README.md#consistent-tagging)"
}

variable "env" {
  type        = string
  description = "Env for tagging and naming. See [doc](../README.md#consistent-tagging)"
}

variable "service" {
  type        = string
  description = "Service for tagging and naming. See [doc](../README.md#consistent-tagging)"
}

variable "owner" {
  type        = string
  description = "Owner for tagging and naming. See [doc](../README.md#consistent-tagging)"
}

variable "bucket_name" {
  type = string
}

variable "bucket_prefix" {
  type        = string
  description = "S3 bucket prefix to allow this role to fetch."
  default     = "/"
}

variable "aws_iam_principal" {
  type        = string
  default     = "arn:aws:iam::713795429718:user/keox-s-ssca5707"
  description = "Snowflake Stage's IAM User, obtained from running the `DESC STAGE` command"
}

variable "external_ids" {
  type        = list(string)
  description = "Snowflake Stage's external IDs, obtained from running the `DESC STAGE` command"
  default     = []
}

variable "max_session_duration_seconds" {
  type        = number
  default     = 60 * 60
  description = "The maximum validity of an STS token."
}
