# NOTE: The following ENV Variables MUST be set, and must point to the machine-to-machine (m2m) Auth0 Application
#     AUTH0_CLIENT_ID
#     AUTH0_CLIENT_SECRET

locals {
  env_seqtoid_org_fqdn     = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  env_seqtoid_org_url      = "https://${local.env_seqtoid_org_fqdn}"
  meta_env_seqtoid_org_url = "https://meta.${local.env_seqtoid_org_fqdn}"
  assets_fqdn              = data.terraform_remote_state.web.outputs.assets_fqdn
}

# TODO: This is created by DEV already
# resource "auth0_role" "admin" {
#   name        = "Admin"
#   description = "Administrator"
# }

resource "auth0_client" "idseq_web" {
  name        = "idseq-web-${var.env}"
  description = "Seqtoid ${var.env} Web Application"
  allowed_clients = [
    # var.auth0_m2m_client_id,
    # local.env_seqtoid_org_url
  ]
  allowed_logout_urls = [
    "http://localhost:3000",
    local.env_seqtoid_org_url,
    local.meta_env_seqtoid_org_url,
  ]
  allowed_origins = [
    "http://localhost:3000",
    local.env_seqtoid_org_url,
    local.meta_env_seqtoid_org_url,
  ]
  app_type = "regular_web"
  callbacks = [
    # "http://localhost:3000/auth/auth0/callback",
    # "http://127.0.0.2:4000/auth/auth0/callback",
    "${local.env_seqtoid_org_url}/auth/auth0/callback",
    # "${local.meta_env_seqtoid_org_url}/auth/auth0/callback",
  ]
  logo_uri = "https://${local.assets_fqdn}/assets/logo-new.png"
  sso      = true
  web_origins = [
    "http://localhost:3000",
    local.env_seqtoid_org_url,
    local.meta_env_seqtoid_org_url,
  ]

  # custom_login_page_on = true
  # is_first_party = true
  # is_token_endpoint_ip_header_trusted = true
  # token_endpoint_auth_method = "client_secret_post"
  # oidc_conformant = false
  # grant_types = [ "authorization_code", "http://auth0.com/oauth/grant-type/password-realm", "implicit", "password", "refresh_token" ]
  # organization_usage = "deny"
  # organization_require_behavior = "no_prompt"

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = 36000
    secret_encoded      = false
  }
}

resource "auth0_client_grant" "idseq_web_grant" {
  client_id    = auth0_client.idseq_web.id
  audience     = "https://${var.auth0_domain}/api/v2/" # "https://${var.env}.seqtoid.org" TODO: Should be this?!!!
  subject_type = "user"
  scopes       = []
}

resource "auth0_client" "idseq_web_management" {
  name     = "idseq-web-${var.env}-management"
  app_type = "non_interactive"
}

resource "auth0_client_grant" "idseq_web_management_grant" {
  client_id = auth0_client.idseq_web_management.id
  audience  = "https://${var.auth0_domain}/api/v2/" # "https://${var.env}.seqtoid.org" TODO: Should be this?!!!
  scopes = [
    "read:users",
    "update:users",
    "delete:users",
    "create:users",
    "create:user_tickets",
    "read:roles",
  ]
}

# TODO: This is created by DEV already
data "auth0_connection" "username_password_authentication" {
  name = "Username-Password-Authentication"
}

resource "auth0_connection_client" "idseq_web_connection_client" {
  connection_id = data.auth0_connection.username_password_authentication.id
  client_id     = auth0_client.idseq_web.id
}

resource "auth0_connection_client" "idseq_web_management_connection_client" {
  connection_id = data.auth0_connection.username_password_authentication.id
  client_id     = auth0_client.idseq_web_management.id
}

#
# resource "auth0_organization" "org" {
#   name         = "staging"
#   display_name = "Staging Org"
#
#   branding {
#     logo_url = "https://${local.assets_fqdn}/assets/CZID_Favicon_Black.png"
#     colors = {
#       primary         = "#f2f2f2"
#       page_background = "#e1e1e1"
#     }
#   }
# }
#
# resource "auth0_organization_connection" "my_org_conn" {
#   organization_id            = auth0_organization.my_organization.id
#   connection_id              = auth0_connection.my_connection.id
#   assign_membership_on_login = true
#   is_signup_enabled          = false
#   show_as_button             = true
# }

data "auth0_client" "idseq_web" {
  client_id = auth0_client.idseq_web.id
}

data "auth0_client" "idseq_web_management" {
  client_id = auth0_client.idseq_web_management.id
}

module "auth0-ssm-params" {
  source  = "github.com/chanzuckerberg/cztack//aws-ssm-params-writer?ref=v0.104.2"
  project = var.project
  env     = var.env
  service = "web" # var.component
  owner   = var.owner

  parameters = {
    AUTH0_CLIENT_ID                = auth0_client.idseq_web.client_id
    AUTH0_CLIENT_SECRET            = data.auth0_client.idseq_web.client_secret
    AUTH0_DOMAIN                   = var.auth0_domain
    AUTH0_MANAGEMENT_CLIENT_ID     = auth0_client.idseq_web_management.client_id
    AUTH0_MANAGEMENT_CLIENT_SECRET = data.auth0_client.idseq_web_management.client_secret
    AUTH0_MANAGEMENT_DOMAIN        = var.auth0_domain
  }
}
