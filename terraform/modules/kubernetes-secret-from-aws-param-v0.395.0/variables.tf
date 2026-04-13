variable "owner" {
  type        = string
  description = "Owner for tagging and naming. See [doc](../README.md#consistent-tagging)."
}

variable "project" {
  type        = string
  description = "Project for tagging and naming. See [doc](../README.md#consistent-tagging)"
}

variable "service" {
  type        = string
  description = "Service for tagging and naming. See [doc](../README.md#consistent-tagging)."
}

variable "env" {
  type        = string
  description = "Env for tagging and naming. See [doc](../README.md#consistent-tagging)."
}

variable "namespace" {
  description = "Kubernetes namespace for all resources. Required if create_secret is true."
  default     = null
  type        = string
}

variable "parameter_store_key_alias" {
  default     = "parameter_store_key"
  description = "Alias of the encryption key used to encrypt parameter store values."
  type        = string
}

variable "aws_ssm_iam_role_name" {
  description = "The IAM role name associated with aws-ssm."
  type        = string
}

variable "secret_name" {
  default = null
  type    = string
}

variable "create_secret" {
  default     = true
  type        = bool
  description = "Create the Kubernetes secret with aws-ssm. If false, only the role and policy are created."
}

variable "iam_path" {
  default     = "/"
  type        = string
  description = "IAM path to create the role in"
}
