
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

variable "iam_role_path" {
  type        = string
  description = "IAM Path for the IAM role created for the service. If omitted, defaults to /{eks_cluster_id}-k8s-core/"
  default     = ""
}

variable "namespace" {
  type        = string
  description = "The k8s namespace to attach to"
}

variable "priority_class" {
  type        = string
  description = "The priority class to use for kiam"
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