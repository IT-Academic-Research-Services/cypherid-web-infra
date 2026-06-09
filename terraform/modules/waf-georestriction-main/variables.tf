variable "enable_visibility" {
  description = "Enable CloudWatch metrics and sampled requests for visibility_config. Default is false."
  type        = bool
  default     = false
}
variable "scope" {
  description = "Specifies whether this is for CLOUDFRONT or REGIONAL."
  type        = string
}

variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

