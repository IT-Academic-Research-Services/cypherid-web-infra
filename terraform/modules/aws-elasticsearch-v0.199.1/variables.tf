variable "project" {}
variable "service" {}
variable "env" {}
variable "owner" {}

variable "domain_name" {
  type = string
}

variable "elasticsearch_version" {
  description = "Supported AWS versions can be found at: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html#aes-choosing-version"
  type        = string
  default     = "7.10"
}

variable "instance_count" {
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
