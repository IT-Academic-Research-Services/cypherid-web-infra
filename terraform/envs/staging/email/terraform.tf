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

# The staging app's CloudWatch log group. Derived from the staging EKS cluster (czid-staging-eks),
# mirroring dev's /aws/eks/czid-dev/seqtoid-web. CONFIRM against the live staging log-group name
# before relying on the CloudWatch deep-link; email + the Grafana link + correlation-id work regardless.
variable "support_log_group" {
  type    = string
  default = "/aws/eks/czid-staging-eks/seqtoid-web"
}

# The Support Inbox is a single central Grafana dashboard (on the dev LGTM stack), filtered by
# correlation_id + env, so staging reports resolve there too. CONFIRM staging logs reach that Loki.
variable "otel_dashboard_base_url" {
  type    = string
  default = "https://grafana.dev.seqtoid.org/d/support-inbox"
}
