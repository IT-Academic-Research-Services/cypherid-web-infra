variable "namespace" {
  type        = string
  description = "The namespace to deploy the nginx ingress controller into"
}


variable "nginx_version" {
  type        = string
  description = "The version of the nginx ingress controller to deploy"
}


variable "enable_metrics" {
  type        = bool
  description = "Enable prometheus metrics for the nginx ingress controller"
  default     = false
}

variable "enable_prometheus_scraping" {
  type        = bool
  description = "Enable prometheus exporter for the nginx ingress controller"
  default     = false
}

variable "extra_args" {
  type        = map(string)
  description = "Extra arguments to pass to the nginx ingress controller"
  default     = {}
}

variable "replicas" {
  type        = number
  description = "The number of replicas to deploy for the nginx ingress controller"
  default     = 3
}

variable "enable_autoscaling" {
  type        = bool
  description = "Enable autoscaling for the nginx ingress controller"
  default     = true
}

variable "min_replicas" {
  type        = number
  description = "The minimum number of replicas for the nginx ingress controller autoscaler"
  default     = 3
}

variable "max_replicas" {
  type        = number
  description = "The maximum number of replicas for the nginx ingress controller autoscaler"
  default     = 10
}

variable "enable_proxy_protocol_v2" {
  type        = bool
  description = "Enable proxy protocol v2 for the nginx ingress controller"
  default     = false
}

variable "extra_config_settings" {
  type        = map(string)
  description = "Extra configuration settings to pass to the nginx ingress controller"
  default     = {}
}

variable "enable_geo_ip_config" {
  type        = bool
  description = "Whether you want to load the MaxMind database into your nginx controller"
  default     = true
}

variable "maxmind_license_key" {
  type        = string
  description = <<EOF
The maxmind contract license key--the contract is owned by SecEng and it's needed to enable geoip configuration. Set directly as a variable since we cannot replicate this secret across accounts.
Since the key is currently in czi-si, you can update the secret like this:
`AWS_PROFILE=czi-si-okta-czi-admin chamber write geoip maxmind_license_key (new key)`
EOF
  default     = ""
  sensitive   = true
}

variable "cluster_geo_restriction" {
  type = object({
    allow   = list(string)
    deny    = list(string)
    default = string
  })
  description = <<EOF
What cluster-wide GeoRestriction to implement, if needed. Requires enable_proxy_protocol_v2 and enable_geo_ip_restriction to be set. Get codes from here: https://www.iso.org/obp/ui/#search"
If apps within this cluster have different restrictions, configure them at the application annotation level. Be careful--relying on variables could break your application.
Here's an example PR with the annotations, assuming enable_geo_ip_config is true and cluster_geo_restriction isn't comprehensive enough:
https://github.com/chanzuckerberg/argus-example-app/pull/285/files
note: this is very prone to outages--a mismatch between k8s-core and your nginx ingress will crash the entire cluster

We can test the effectiveness of this geo restriction by running tests with the relevant datadog at https://app.datadoghq.com/synthetics 
EOF
  validation {
    condition     = var.cluster_geo_restriction == null || contains(["allow", "deny"], var.cluster_geo_restriction.default)
    error_message = "The default key must have a string \"allow\" or \"deny\""
  }
  default = null
}

variable "proxy_body_size" {
  type        = string
  description = "Maximum size of the request body that NGINX will accept"
  default     = "10M" # M = Mb
}

variable "controller_cpu_request" {
  type        = string
  description = "CPU request for each nginx ingress controller pod"
  default     = "2000m"
}
variable "controller_memory_request" {
  type        = string
  description = "Memory request for each nginx ingress controller pod"
  default     = "2Gi"
}

variable "external_traffic_policy" {
  type        = string
  description = <<EOT
Whether to route external traffic to node-local (Local) or cluster-wide (Cluster) endpoints. 
Tradeoffs explained here: https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/
EOT
  default     = "Cluster"
  validation {
    condition     = var.external_traffic_policy == "Local" || var.external_traffic_policy == "Cluster"
    error_message = "Valid values for var.external_traffic_poicy are ('Local', 'Cluster')"
  }
}

variable "linkerd_annotations" {
  type = object({
    proxy_wait_before_exit_seconds = optional(string, "45")
    linkerd_inject                 = optional(string, "enabled")
  })
  description = "Annotations to add to the nginx ingress controller pods for linkerd"
  default     = {}
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

variable "tags" {
  description = "Standard tags. Typically generated by fogg"
  type = object({
    env : string,
    owner : string,
    project : string,
    service : string,
    managedBy : string,
  })
}