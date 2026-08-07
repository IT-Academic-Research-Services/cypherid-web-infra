provider "aws" {
  region  = "us-west-2"
  profile = "idseq-dev"

  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["491013321714"]
}

terraform {
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-491013321714-test"
    key          = "terraform/idseq/envs/dev/components/alerting.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-dev"
  }
}

variable "env" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "idseq"
}

variable "component" {
  type    = string
  default = "alerting"
}

variable "owner" {
  type    = string
  default = "idseq-eng"
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
  default = {
    project = "idseq"
    env     = "dev"
    service = "alerting"
    owner   = "idseq-eng"
  }
}

# The Slack channel's email-to-channel address. Not committed -- default "" keeps `terraform plan`
# apply-safe in CI (mirrors monitoring's alarm_actions_sns_topic_arn). Apply MUST set the real value
# via TF_VAR_alert_email.
variable "alert_email" {
  type    = string
  default = ""
}
