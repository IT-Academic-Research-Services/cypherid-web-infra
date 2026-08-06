variable "name_prefix" {
  type        = string
  description = "Prefix for every resource name, e.g. \"seqtoid-staging\". Matches the CLI-built resources so `terraform import` adopts them cleanly."
}

variable "env_label" {
  type        = string
  description = "Human label shown in the Slack message header, e.g. \"env-staging\" or \"dev\"."
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "tags" {
  type = object({
    project = string
    env     = string
    service = string
    owner   = string
  })
}

variable "alert_email" {
  type        = string
  description = "Destination for the SNS email subscription -- the Slack channel's email-to-channel address. Requires a one-time click-Confirm in the channel."
}

variable "check_url" {
  type        = string
  description = "Public URL the synthetic canary probes on a schedule, e.g. https://env-staging.seqtoid.org/."
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of the web ALB (app/<name>/<id>) used for the HealthyHostCount alarm."
}

variable "target_group_arn_suffixes" {
  type        = list(string)
  description = "ARN suffixes (targetgroup/<name>/<id>) of the blue AND green target groups. The alarm sums HealthyHostCount across all of them so a blue/green promotion never false-alarms."
  validation {
    condition     = length(var.target_group_arn_suffixes) >= 1
    error_message = "Provide at least one target group ARN suffix (typically two for a blue/green rollout)."
  }
}

variable "canary_schedule" {
  type    = string
  default = "rate(1 minute)"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}
