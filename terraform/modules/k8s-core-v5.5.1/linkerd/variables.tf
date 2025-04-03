variable "linkerd_namespace" {
  description = "The namespace to install linkerd into"
  type        = string
  default     = "linkerd"
}
  
variable "linkerd_control_plane_chart_version" {
  description = "The version of the linkerd control plane chart to install"
  type        = string
}

variable "linkerd_crd_chart_version" {
  description = "The version of the linkerd crd chart to install"
  type        = string
}
  
variable "tls_private_key_algorithm" {
  description = "The algorithm to use for the private key"
  type        = string
  default     = "ECDSA"
}
  
variable "tls_private_key_ecdsa_curve" {
  description = "The ECDSA curve to use for the private key"
  type        = string
  default     = "P256"
}

variable "tls_private_key_param_path" {
  description = "The parameter store path to the ca private key"
  type        = string
  default     = ""
}

variable "tls_private_cert_param_path" {
  description = "The parameter store path to the ca cert"
  type        = string
  default     = ""
}
  
variable "validity_period_hours_of_root_ca" {
  description = "The validity period in hours of the root CA"
  type        = number
  default     = 24 * 365 * 10 # 10 years
}
  
variable "early_renewal_hours_of_root_ca" {
  description = "The early renewal period in hours of the root CA"
  type        = number
  default     = 24 * 30 * 12  # 12 months
}

variable "linkerd_trust_anchor_secret_name" {
  description = "The name of the secret to store the linkerd trust anchor in"
  type        = string
  default     = "linkerd-trust-anchor"
}
  
variable "proxy_certificate_duration" {
  description = "How long the proxy certificate should be valid for"
  type        = string
  default     = "48h0m0s"
}

variable "proxy_certificate_renew_before" {
  description = "How to wait before renewing the proxy certificate"
  type        = string
  default     = "25h0m0s"
}

variable "linkerd_identity_issuer" {
  description = "The name of the linkerd identity issuer"
  type        = string
  default     = "linkerd-identity-issuer"
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
