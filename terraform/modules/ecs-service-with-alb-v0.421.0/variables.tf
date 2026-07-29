variable "project" {
  type        = string
  description = "Project for tagging and naming. See [doc](../README.md#consistent-tagging)"
}

variable "service" {
  type        = string
  description = "Service for tagging and naming. See [doc](../README.md#consistent-tagging)."
}

variable "env" {
  type        = string
  description = "Env for tagging and naming. See [doc](../README.md#consistent-tagging)."
}

variable "owner" {
  type        = string
  description = "Owner for tagging and naming. See [doc](../README.md#consistent-tagging)."
}

variable "extra_tags" {
  type        = map(string)
  description = "Extra tags that will be added to components created by this module."
  default     = {}
}

variable "cluster_id" {
  type = string
}

variable "desired_count" {
  type = string
}

variable "lb_subnets" {
  description = "List of subnets in which to deploy the load balancer."
  type        = list(string)
}

variable "fargate_task_subnets" {
  description = "List of private_subnets in which to deploy the Fargate task."
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  type = string
}

variable "container_name" {
  description = "Name of the container. Must match name in task definition. If omitted, defaults to name derived from project/env/service."
  type        = string
  default     = ""
}

variable "container_port" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "route53_zone_id" {
  description = "Zone in which to create an alias record to the ALB."
  type        = string
}

variable "subdomain" {
  description = "Subdomain in the zone. Final domain name will be subdomain.zone"
  type        = string
}

variable "task_role_arn" {
  type = string
}

variable "task_definition" {
  description = "JSON to describe task. If omitted, defaults to a stub task that is expected to be managed outside of Terraform."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "Certificate for the HTTPS listener."
  type        = string
}

variable "ssl_policy" {
  description = "Probably don't touch this."
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
}

# TODO: Defaults should be more restrictive.
# Idea: create internal and internet facing modules that set these variables.
variable "lb_egress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "lb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "lb_idle_timeout_seconds" {
  type    = number
  default = 60
}

variable "internal_lb" {
  type    = bool
  default = false
}

variable "health_check_matcher" {
  type        = string
  description = "Range of HTTP status codes considered success for health checks. [Doc](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html#matcher)"
  default     = "200-399"
}

variable "disable_http_redirect" {
  description = "Disable redirecting HTTP to HTTPS."
  default     = "true"
  type        = string
}

variable "health_check_timeout" {
  description = "Timeout for a health check of the underlying service."
  type        = number
  default     = null
}

variable "health_check_interval" {
  description = "Time between health checks of the underlying service."
  type        = number
  default     = null
}

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 7200. Only valid for services configured to use load balancers."
  default     = "60"
}

variable "use_fargate" {
  description = "Launch this service on Fargate if true, on EC2 instances if false."
  type        = bool
  default     = false
}

variable "fargate_cpu" {
  description = "CPU units for Fargate task. Used if task_definition provided, or for initial stub task if externally managed."
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Memory in megabytes for Fargate task. Used if task_definition provided, or for initial stub task if externally managed."
  type        = number
  default     = 512
}

variable "fargate_subnets" {
  description = "Subnets to launch Fargate task in. Must be present if use_fargate is true."
  type        = list(string)
  default     = []
}

variable "fargate_security_group_ids" {
  description = "Security group to use for the Fargate task. A possible default group can be found in data.terraform_remote_state.ecs.outputs.security_group_id"
  type        = list(string)
  default     = []
}

variable "registry_secretsmanager_arn" {
  description = "ARN for AWS Secrets Manager secret for credentials to private registry"
  type        = string
  default     = ""
}

variable "with_service_discovery" {
  description = "Register the service with ECS service discovery. Adds a sub-zone to the given route53_zone_id. Requires with_fargate=true"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket to write alb access logs to. Empty for no access logs."
  default     = ""
  type        = string
}

variable "alb_protocol" {
  type = object({
    protocol : string,
    version : string,
  })
  default = {
    protocol = "HTTP"
    version  = null
  }
  description = "Specify the ALB protocol version to use. Modify, for example, if you need HTTP/2 or gRPC."
}

# Dev migrated to EKS/Argo: the app + resque now run as k8s pods and the ECS cluster was torn
# down, so creating an ECS service there fails with ClusterNotFoundException. This lets a caller
# keep the ALB / target group / task definition (which still exist and are still referenced)
# while NOT creating the ECS service. Defaults to true so staging/prod -- still on ECS -- are
# completely unaffected. See platform-overhaul #687.
variable "create_service" {
  type        = bool
  default     = true
  description = "Create the ECS service. Set false where the workload has moved off ECS (e.g. dev on EKS)."
}

# Manage the app's Route53 records (the apex A record and, when HTTP redirect is on, the AAAA and
# www records). Set FALSE where a Kubernetes Ingress owns the edge: the AWS load-balancer controller
# creates its own ALB and external-dns owns the records, so terraform declaring them too means two
# owners fighting -- and terraform, believing it still owns them, would repoint the hostname at the
# now-empty ECS ALB. Defaults true so ECS-fronted envs (staging/prod) are unaffected. See #693.
variable "manage_dns_records" {
  type        = bool
  default     = true
  description = "Manage the service's Route53 records. Set false where a k8s Ingress + external-dns own the edge."
}
