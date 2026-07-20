variable "project" {
  type = string
}

variable "service" {
  type = string
}

variable "env" {
  type = string
}

variable "owner" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "elasticsearch_version" {
  description = "Supported AWS versions can be found at: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html#aes-choosing-version"
  type        = string
  default     = "7.10"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "instance_type" {
  type    = string
  default = "m4.large.elasticsearch"
}

variable "availability_zone_count" {
  description = "Number of Availability Zones for the domain to use with zone_awareness_enabled. Defaults to 2. Valid values: 2 or 3."
  type        = number
  default     = 2
}

variable "access_policy_arns" {
  type    = list(any)
  default = ["*"]
}

variable "ebs_volume_size" {
  description = "The size of EBS volumes attached to data nodes (in GB)."
  type        = number
  default     = 512
}

variable "ebs_volume_type" {
  description = "The type of EBS volumes attached to data nodes."
  type        = string
  default     = "gp2"
}

variable "vpc_id" {
  type = string
}

variable "vpc_subnet_ids" {
  type = list(any)
}

variable "ingress_cidrs" {
  type    = string
  default = "0.0.0.0/0"
}

variable "egress_cidrs" {
  type    = string
  default = "0.0.0.0/0"
}

variable "log_publishing_options" {
  description = "List of maps containing configuration of log publishing options."
  type = object({
    cloudwatch_log_group : string
  })
}

variable "custom_sg_ids" {
  description = "List of IDs pointing to custom security groups"
  type        = list(string)
  default     = []
}

# CZID-726: dedicated master nodes (optional, off by default so existing
# callers keep their current single-tier topology).
variable "dedicated_master_enabled" {
  description = "Run dedicated master nodes so data nodes stop absorbing cluster-management churn."
  type        = bool
  default     = false
}

variable "dedicated_master_type" {
  description = "Instance type for dedicated master nodes. Only used when dedicated_master_enabled = true."
  type        = string
  default     = null
}

variable "dedicated_master_count" {
  description = "Number of dedicated master nodes. Must be an odd number (3 recommended) for quorum. Only used when dedicated_master_enabled = true."
  type        = number
  default     = 3
}

variable "auto_tune_desired_state" {
  description = "Auto-Tune desired state: ENABLED or DISABLED. ENABLED applies AWS JVM/queue tuning recommendations."
  type        = string
  default     = "DISABLED"
}
