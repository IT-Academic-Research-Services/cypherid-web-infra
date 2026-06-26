data "sentry_organization" "seqtoid" {
  slug = var.organization
}

resource "sentry_team" "seqtoid_env" {
  organization = data.sentry_organization.seqtoid.slug
  name         = "SeqtoID ${var.env} Team"
}

resource "sentry_project" "seqtoid_web_backend" {
  organization = sentry_team.seqtoid_env.organization
  teams        = [sentry_team.seqtoid_env.slug]
  name         = "${var.env} Rails Project"
  platform     = "ruby-rails"
  default_key  = false
}

resource "sentry_project" "seqtoid_web_frontend" {
  organization = sentry_team.seqtoid_env.organization
  teams        = [sentry_team.seqtoid_env.slug]
  name         = "${var.env} ReactJS Project"
  platform     = "javascript-react"
  default_key  = false
}

resource "sentry_key" "seqtoid_web_backend" {
  organization = sentry_project.seqtoid_web_backend.organization
  project      = sentry_project.seqtoid_web_backend.slug
  name         = "Backend Key"
}

resource "sentry_key" "seqtoid_web_frontend" {
  organization = sentry_project.seqtoid_web_frontend.organization
  project      = sentry_project.seqtoid_web_frontend.slug
  name         = "Frontend Key"
}

module "sentry-ssm-params" {
  source  = "github.com/chanzuckerberg/cztack//aws-ssm-params-writer?ref=v0.104.2"
  project = var.project
  env     = var.env
  service = "web"
  owner   = var.owner

  parameters = {
    SENTRY_DSN_BACKEND  = sentry_key.seqtoid_web_backend.dsn.secret
    SENTRY_DSN_FRONTEND = sentry_key.seqtoid_web_frontend.dsn.secret
  }
}
