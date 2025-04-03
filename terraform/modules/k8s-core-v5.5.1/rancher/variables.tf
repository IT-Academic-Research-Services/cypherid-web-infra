variable "provisioner_image" {
  default     = "rancher/hyperkube:v1.26.4-rancher2"
  type        = string
  description = "Provisioner image to use (needs kubectl installed)"
}

variable "eks_cluster" {
  type = object({
    cluster_id : string,
    cluster_arn : string,
    cluster_endpoint : string,
    cluster_ca : string,
    cluster_oidc_issuer_url : string,
    cluster_version : string,
    worker_iam_role_name : string,
    worker_security_group : string,
    oidc_provider_arn : string,
  })
  description = "EKS cluster information"
}

variable "cluster_monitoring" {
  type = object({
    enabled : optional(bool,true),
    chart_version : optional(string, "102.0.3+up40.1.2"),
  })
  description = "Cluster monitoring configuration"
}