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

# ---------------------------------------------------------------------------
# CZID-726: stability hardening for czid-dev-heatmap-es.
#
# Symptom: the 2-data-node, zone-aware, NO-dedicated-master domain lost a node
# ~twice/week (AWS/ES Nodes Minimum=1 on 07-10 and 07-12). Both nodes are
# data+master-eligible, so every AWS host-health node replacement churns cluster
# management, and a 2-node master set has no quorum margin. That churn is the
# upstream trigger for the worker connect-timeouts (retry mitigation in #723).
#
# Fix: add 3 dedicated master nodes so cluster management leaves the data nodes,
# and turn on Auto-Tune to relieve JVM heap pressure on the burstable t3.small
# data nodes. Data-node type/count are unchanged.
#
# Cost (us-west-2 on-demand, approx): +3x t3.small.search dedicated masters at
# ~$0.036/hr ~= +$79/mo (~+$948/yr). Data nodes unchanged (~$52/mo). Dev only.
# ---------------------------------------------------------------------------

variable "es_dedicated_master_enabled" {
  description = "Run dedicated master nodes for the heatmap-es domain."
  type        = bool
  default     = true
}

variable "es_dedicated_master_type" {
  description = "Instance type for the dedicated master nodes."
  type        = string
  default     = "t3.small.elasticsearch"
}

variable "es_dedicated_master_count" {
  description = "Dedicated master node count. Odd number for quorum (3 recommended)."
  type        = number
  default     = 3
}

variable "es_auto_tune_desired_state" {
  description = "Auto-Tune desired state for the heatmap-es domain (ENABLED or DISABLED)."
  type        = string
  default     = "ENABLED"
}
