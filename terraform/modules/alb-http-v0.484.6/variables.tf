variable "project" {}

variable "env" {
  type = string
}

variable "service" {}

variable "subnets" {
  description = "List of subnets for the ALB."
  type        = list(string)
}

variable "vpc_id" {
  type = string
}

variable "certificate_arn" {
  description = "Certificate for the HTTPS listener."
  type        = string
}

variable "ssl_policy" {
  description = "Probably don't touch this."
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
}

# TODO: Defaults should be more restrictive.
# Idea: create internal and internet facing modules that set these variables.
variable "egress_cidrs" {
  type        = list(string)
  description = "CIDRs that the load balancer is allowed to initiate outbound traffic to. Ignored if create_security_group is false."
  default     = ["0.0.0.0/0"]
}

variable "ingress_cidrs" {
  type        = list(string)
  description = "CIDRs that the load balancer is allowed to accept inbound traffic from. Ignored if create_security_group is false."
  default     = ["0.0.0.0/0"]
}

variable "security_group_ids" {
  description = "List of security group IDs for the ALB."
  type        = list(string)
  default     = []
}

variable "idle_timeout" {
  type    = number
  default = 60
}

variable "owner" {}

variable "internal" {
  type    = bool
  default = false
}

variable "target_group_arn" {
  type    = string
  default = ""
}

variable "disable_http_redirect" {
  description = "Disable redirecting HTTP connections to HTTPS."
  type        = bool
  default     = false
}

variable "create_security_group" {
  description = "Create a default security group that accepts all traffic from ingress_cidrs 80/443, and allows traffic to the given egress_cidrs."
  type        = bool
  default     = true
}

variable "access_logs_bucket" {
  description = "S3 bucket to write alb access logs to."
  default     = ""
}
