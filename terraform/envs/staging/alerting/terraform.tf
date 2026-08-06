provider "aws" {
  region  = "us-west-2"
  profile = "idseq-staging"

  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["030998640247"]
}

terraform {
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-030998640247"
    key          = "terraform/idseq/envs/staging/components/alerting.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-staging"
  }
}

variable "env" {
  type    = string
  default = "staging"
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
    env     = "staging"
    service = "alerting"
    owner   = "idseq-eng"
  }
}

# The Slack channel's email-to-channel address. Secret-ish (anyone with it can post to the channel),
# so it is NOT defaulted here -- set via TF_VAR_alert_email at apply time.
variable "alert_email" {
  type = string
}
