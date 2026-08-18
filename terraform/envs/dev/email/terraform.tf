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
    key          = "terraform/idseq/envs/dev/components/email.tfstate"
    encrypt      = true
    region       = "us-west-2"
    profile      = "idseq-dev"
  }
}

# The env's seqtoid.org subdomain zone (dev.seqtoid.org) -- same source dev/web uses.
data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {
    bucket  = "tfstate-491013321714-test"
    key     = "terraform/idseq/envs/dev/components/route53.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"
  }
}

variable "env" {
  type    = string
  default = "dev"
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
  default = "/idseq-dev-web/"
}

# The support deep-link targets: the app's CloudWatch log group and the Grafana Support Inbox
# dashboard. These make SupportRequestsController#build_log_links resolve (else TODO placeholders).
variable "support_log_group" {
  type    = string
  default = "/aws/eks/czid-dev/seqtoid-web"
}

variable "otel_dashboard_base_url" {
  type    = string
  default = "https://grafana.dev.seqtoid.org/d/support-inbox"
}
