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

variable "terminate_target_tag_key" {
  description = "Instance tag KEY that ec2:TerminateInstances is constrained to. MUST match the FIS experiment template's target resource_tag key, so the role can only ever terminate instances the template selects."
  type        = string
  default     = "karpenter.sh/nodepool"
}

variable "terminate_target_tag_values" {
  description = "Allowed values of terminate_target_tag_key. FIS may terminate an instance only when its tag value is in this list -- keep it in lockstep with the template's target resource_tag value."
  type        = list(string)
}
