variable "snowflake_external_ids" {
  type        = list(string)
  default     = []
  description = "define this in the TFE workspace UI"
}

variable "snowflake_iam_principal" {
  type        = string
  default     = ""
  description = "define this in the TFE workspace UI"
}
