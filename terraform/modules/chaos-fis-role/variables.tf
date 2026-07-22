variable "cluster_name" {
  description = "EKS cluster name; used to name the FIS role/policy per env."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary applied to the FIS role (env account policy)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the FIS role and policy."
  type        = map(string)
  default     = {}
}
