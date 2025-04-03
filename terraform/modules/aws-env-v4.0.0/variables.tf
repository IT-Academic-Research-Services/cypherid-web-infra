variable "vpc_name_suffix" {
  description = "Suffix to append to the VPC name, like `-$${var.service}`, defaults to blank for backwards compatibility"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "IP address range for the VPC."
  type        = string
}

variable "azs" {
  description = "EC2 availability zones for the VPC."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "public_subnet_cidrs" {
  description = "List of IP ranges for the public subnets. Must be same length as var.azs."
  type        = list(any)
}

variable "private_subnet_cidrs" {
  description = "List of IP ranges for the private subnets. Must be same length as var.azs."
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "List of IP ranges for the database subnets. Must be same length as var.azs."
  type        = list(string)
}

variable "bastion_config" {
  description = <<EOF
  Grouping the bastion-specific configuration variables in one variable instead of disjoint. 
  Here's an example one to copy-paste:
  ```
  {
    zone_id = <from route53>
    subdomain = "bastion"
    ssh_users = []
    instance_type = "t3.medium"
    allowed_cidr_blocks = {
      ingress: ["0.0.0.0/0"], 
      egress: ["0.0.0.0/0"]
    }
    ebs_volume_type = "gp3"
    ssh_key_name = "infra-tools"
    czi_security_update = true
  }
  ```
  EOF
  type = object({
    zone_id             = string
    subdomain           = string
    ssh_users           = list(object({ username : string, sudo_enabled : bool }))
    instance_type       = string
    allowed_cidr_blocks = object({ ingress : list(string), egress : list(string) })
    ebs_volume_type     = string
    czi_security_update = bool
    ssh_key_name        = string
  })
  default = null
}

variable "create_database_subnet_route_table" {
  type        = bool
  default     = false
  description = "Controls if separate route table for database should be created."
}

variable "datadog_api_key" {
  type        = string
  default     = ""
  description = "A datadog api key to enable the datadog agent on bastions."
}

variable "service" {
  type        = string
  description = "The service. Aka cloud-env"
}

variable "owner" {
  type = string
}

variable "project" {
  description = "A high level name, typically the name of the site."
  type        = string
}

variable "env" {
  description = "The environment / stage. Aka staging, dev, prod."
  type        = string
}

# variable "bastion_ebs_volume_type" {
#   description = "EBS volume type for Bastion hosts, defaults to GP3"
#   type        = string
#   default     = "gp3"
# }

variable "k8s_cluster_names" {
  description = "A list of k8s cluster names that will live in this vpc. We use these to tag vpc resources appropriately. See https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html"
  type        = list(string)
  default     = []
}

variable "disable_auto_security_update" {
  type        = bool
  description = "Disable auto-rotation of bastion instances to pick up most recent security updates"
  default     = false
}

variable "vpc_flow_log_retention_in_days" {
  type        = number
  description = "Number of days to retain VPC flow logs."
  default     = 0
}

variable "skip_az_checks" {
  description = "Do not set to true for new VPCs; used to support legacy VPCs that violate 1:1 az to subnet constraint"
  default     = false
  type        = bool
}
