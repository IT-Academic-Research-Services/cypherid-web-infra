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
    key          = "terraform/idseq/envs/staging/components/email.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-staging"
  }
}

# The env's seqtoid.org subdomain zone (staging.seqtoid.org) -- same source staging/web uses.
data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {
    bucket  = "tfstate-030998640247"
    key     = "terraform/idseq/envs/staging/components/route53.tfstate"
    region  = "us-west-2"
    profile = "idseq-staging"
  }
}

variable "env" {
  type    = string
  default = "staging"
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
    service = "email"
    owner   = "idseq-eng"
  }
}

# The ServiceNow inbound address support reports are emailed to.
variable "support_inbox_email" {
  type    = string
  default = "seqtoid-support@ucsf.edu"
}

# Off by default: leave "" so this stack provisions SES only. Set to the app's chamber path
# (e.g. "/idseq-staging-web/") to also write SMTP_USER/PASSWORD/MAIL_FROM_ADDRESS/SUPPORT_INBOX_EMAIL.
variable "chamber_ssm_prefix" {
  type    = string
  default = ""
}

variable "support_log_group" {
  type    = string
  default = ""
}

variable "otel_dashboard_base_url" {
  type    = string
  default = ""
}
