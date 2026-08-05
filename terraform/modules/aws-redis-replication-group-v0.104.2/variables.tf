
variable "tags" {
  type        = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  description = "Tags to apply"
}

variable "subnets" {
  type        = list(string)
  description = "List of subnets to which this EC instance should be attached. They should probably be private."
}

variable "preferred_cache_cluster_azs" {
  type        = list(string)
  description = "Availability zone in which this instance should run."
  default     = null
}

variable "ingress_security_group_ids" {
  type        = list(string)
  description = "Source security groups which should be able to contact this instance."
}

variable "port" {
  type        = number
  description = "Port to host Redis on."
  default     = 6379
}

variable "instance_type" {
  type        = string
  description = "The type of instance to run. See [supported node types](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheNodes.SupportedTypes.html)"
  default     = "cache.m5.large"
}

variable "parameter_group_name" {
  type        = string
  description = "Parameter group to use for this Redis cache."
  default     = "default.redis5.0"
}

variable "engine_version" {
  type        = string
  description = "The version of Redis to run. See [supported versions](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/supported-engine-versions.html)"
  default     = "7.0"
}

variable "apply_immediately" {
  type        = bool
  description = "Whether changes should be applied immediately or during the next maintenance window."
  default     = true
}

# This is to get a around a limitation where the elasticache cluster id can be
# only 20 characters long. Use it only if you get that error.
variable "resource_name" {
  description = "If not set, name will be [var.project]-[var.env]-[var.name]."
  type        = string
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC where the cache will be deployed."
}

variable "number_cache_clusters" {
  type        = number
  description = "Number of cache clusters. Default 2 because if Multi-AZ is enabled, the number of nodes needs to be exactly 2 to avoid sharding across different nodes."
  default     = 2
}

variable "at_rest_encryption_enabled" {
  type        = bool
  description = "Whether to enable encryption at rest. Default: true."
  default     = true
}

variable "transit_encryption_enabled" {
  type        = bool
  description = "Whether to enable encryption in transit. Default: true."
  default     = true
}

variable "description" {
  type        = string
  description = "A user-created description for the replication group."
}

variable "parameter_group_family" {
  type        = string
  description = "The cluster's parameter group family. Redis options [here](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/ParameterGroups.Redis.html)"
  default     = "redis7"
}

variable "parameters" {
  type        = list(map(any))
  default     = []
  description = "Redis database parameters in name-value pairs. Use the parameter group family to find parameters [here](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/ParameterGroups.Redis.html)"
}

variable "auth_token" {
  type        = string
  description = "Token for accessing the elasticache cluster"
  sensitive   = true
}

# --- Backup (added 2026-08-05) -------------------------------------------------
# Days of automatic ElastiCache snapshots to retain. The upstream cztack module exposed no snapshot
# settings, so every caller ran on the AWS default of 0 -- NO backup at all. Default 0 here preserves
# that exactly for any caller that does not opt in, so prod and the legacy czid-staging plan unchanged.
variable "snapshot_retention_limit" {
  type        = number
  description = "Days of automatic snapshots to retain. 0 disables backup entirely (the prior behaviour)."
  default     = 0
}

# Daily UTC snapshot window, e.g. "08:00-09:00". Empty -> not set -> AWS assigns one. Must not overlap
# the maintenance window.
variable "snapshot_window" {
  type        = string
  description = "Daily UTC window in which the snapshot is taken. Empty = let AWS assign."
  default     = ""
}
