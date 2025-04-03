variable "service" {
  type    = string
  default = "ecs"
}

variable "owner" {
  type = string
}

variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "env" {
  type = string
}

variable "min_servers" {
  description = "Minimum number of instances for the cluster."
  default     = 1
  type        = number
}

variable "max_servers" {
  description = "Maximum number of instances for the cluster. Must be at least var.min_servers + 1."
  default     = 2
  type        = number
}

variable "instance_type" {
  type = string
}

variable "subnets" {
  description = "List of subnets in which to deploy the cluster."
  type        = list(string)
}

variable "vpc_id" {
  type = string
}

variable "datadog_api_key" {
  type        = string
  default     = ""
  description = "A datadog api key to enable the datadog agent on the instance"
}

variable "ssh_key_name" {
  type = string
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "ami" {
  type        = string
  default     = ""
  description = "Specify which ECS AMI image you want to run. Otherwise uses the CZI ECS AMI."
}

variable "associate_public_ip_address" {
  default = false
  type    = bool
}

variable "docker_storage_size" {
  default     = "100"
  description = "EBS Volume size in Gib that the ECS Instance uses for Docker images and metadata "
  type        = string
}

variable "ec2_extra_tags" {
  description = "Extra tags to apply to EC2 instances in the cluster."
  type        = map(string)
  default     = {}
}

variable "iam_path" {
  default     = "/"
  description = "IAM path, this is useful when creating resources with the same name across multiple regions. Defaults to /"
  type        = string
}

variable "registrator_image" {
  default     = "gliderlabs/registrator:latest"
  description = "Image to use when deploying registrator agent, defaults to the gliderlabs registrator:latest image"
  type        = string
}

variable "security_group_ids" {
  type        = list(string)
  description = "A list of Security group IDs to apply to the launch configuration"
  default     = []
}

variable "additional_user_data_script" {
  description = "A script that gets executed at ec2 machine boot time."
  default     = ""
  type        = string
}

variable "ssh_users" {
  description = "A list of ssh users that will get created on each ec2 instance. Defaults to sudo enabled."
  type        = list(object({ username : string, sudo_enabled : bool }))
  default     = []
}

variable "cluster_asg_rolling_interval_hours" {
  type        = string
  description = "If set to a positive value, this will cycle an instance every N hours, replacing it with a new one."
  default     = 0
}

variable "ecs_cluster_name" {
  type        = string
  description = "override the default cluster name"
  default     = ""
}

variable "heartbeat_timeout" {
  description = "Heartbeat Timeout setting for how long it takes for the graceful shutodwn hook takes to timeout. This is useful when deploying clustered applications that benifit from having a deploy between autoscaling create/destroy actions. Defaults to 180"
  default     = "180"
  type        = string
}

variable "log_retention_in_days" {
  type        = number
  description = "N of days you want to retain log events. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, and 0."
  default     = 0
}