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

# The app's chamber path (CHAMBER_SERVICE defaults to idseq-<env>-web; the IRSA role reads
# /idseq-<env>-web/*). Setting it makes this stack also write the app's mail env vars.
variable "chamber_ssm_prefix" {
  type    = string
  default = "/idseq-staging-web/"
}

# Empty on purpose. The seqtoid-web pods ship container logs to Loki (the Grafana LGTM stack), NOT
# to CloudWatch -- there is no /aws/eks/<cluster>/seqtoid-web log group in any env. Left unset, the
# app omits the (dead) CloudWatch Logs deep-link from support tickets and keeps the working Grafana
# Support Inbox link (OTEL_DASHBOARD_BASE_URL). Set a real group only if app->CloudWatch logging is added.
variable "support_log_group" {
  type    = string
  default = ""
}

# The Support Inbox is a single central Grafana dashboard (on the dev LGTM stack), filtered by
# correlation_id + env, so staging reports resolve there too. CONFIRM staging logs reach that Loki.
variable "otel_dashboard_base_url" {
  type    = string
  default = "https://grafana.dev.seqtoid.org/d/support-inbox"
}
