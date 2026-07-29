# ---------------------------------------------------------------------------
# OpenSearch (heatmap-es) sizing — SSOT per-env inputs (CZID-290 / #246)
#
# Dev is intentionally minimal. Defaults preserve the current dev sizing (no
# behavior change); they are surfaced as explicit variables so sizing is a
# reviewable SSOT input rather than hardcoded inline in esdomain.tf.
# ---------------------------------------------------------------------------

variable "es_instance_type" {
  description = "OpenSearch data-node instance type for the heatmap-es domain."
  type        = string
  default     = "t3.small.elasticsearch"
}

variable "es_instance_count" {
  description = "OpenSearch data-node count for the heatmap-es domain. Keep even for 2-AZ zone awareness."
  type        = number
  default     = 2
}

variable "es_ebs_volume_type" {
  description = "EBS volume type for OpenSearch data nodes."
  type        = string
  default     = "gp3"
}

variable "es_ebs_volume_size" {
  description = "EBS volume size (GB) per OpenSearch data node."
  type        = number
  default     = 16
}
