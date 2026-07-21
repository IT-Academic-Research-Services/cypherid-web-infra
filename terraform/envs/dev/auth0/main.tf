# NOTE: The following ENV Variables MUST be set, and must point to the machine-to-machine (m2m) Auth0 Application
#     AUTH0_CLIENT_ID
#     AUTH0_CLIENT_SECRET
#     AUTH0_DOMAIN (optional)

# resource "auth0_client" "global" {
#   name                 = "All Applications"
#   custom_login_page    = file("${path.module}/pages/login.html")
#   custom_login_page_on = true
#
#   refresh_token {
#     rotation_type   = "non-rotating"
#     expiration_type = "non-expiring"
#   }
# }

locals {
  env_seqtoid_org_fqdn      = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  env_seqtoid_org_url       = "https://${local.env_seqtoid_org_fqdn}"
  env_seqtoid_org_zone_id   = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id
  auth_env_seqtoid_org_fqdn = "auth.${local.env_seqtoid_org_fqdn}"
  # meta_env_seqtoid_org_url = "https://meta.${local.env_seqtoid_org_fqdn}"
  assets_fqdn = data.terraform_remote_state.web.outputs.assets_fqdn
  assets_url  = "https://${local.assets_fqdn}"

  # Per-PR preview sandboxes serve on pr-<N>.dev.seqtoid.org (the preview ApplicationSet sets
  # ingress.host = pr-{{.number}}.dev.seqtoid.org, #616/#619). PR numbers are unbounded, so the
  # callback allowlist cannot enumerate them; Auth0 permits a single `*` in the LEFTMOST subdomain,
  # which covers every current and future sandbox in one entry.
  #
  # DEV ONLY -- DO NOT COPY THIS TO staging/prod.
  # A wildcard callback means ANY host under dev.seqtoid.org can receive an OAuth authorization
  # code for this client, so a dangling or attacker-controlled subdomain in this zone becomes a
  # code-theft path. That is an accepted risk in dev (we control the zone; external-dns only
  # publishes records for our own ALBs, and the tenant holds no real user data) and an
  # unacceptable one anywhere real. staging/prod must keep enumerating exact callback URLs.
  # Approved by Tom 2026-07-16 for the dev tenant only.
  preview_sandbox_wildcard_url = "https://*.${local.env_seqtoid_org_fqdn}"
}

resource "auth0_custom_domain" "auth_env_seqtoid_org" {
  domain     = local.auth_env_seqtoid_org_fqdn
  type       = "auth0_managed_certs"
  tls_policy = "recommended"
  # domain_metadata = {}
}

# Map the CNAME verification record required by Auth0
resource "aws_route53_record" "auth_env_cname" {
  zone_id = local.env_seqtoid_org_zone_id
  name    = auth0_custom_domain.auth_env_seqtoid_org.verification[0].methods[0].domain
  type    = auth0_custom_domain.auth_env_seqtoid_org.verification[0].methods[0].name
  ttl     = 300

  records = [
    auth0_custom_domain.auth_env_seqtoid_org.verification[0].methods[0].record
  ]
}

resource "auth0_custom_domain_verification" "auth_env_cname" {
  custom_domain_id = auth0_custom_domain.auth_env_seqtoid_org.id

  depends_on = [aws_route53_record.auth_env_cname]
}

resource "auth0_custom_domain_default" "auth_env_seqtoid_org" {
  domain = auth0_custom_domain.auth_env_seqtoid_org.domain

  depends_on = [auth0_custom_domain_verification.auth_env_cname]
}

resource "auth0_tenant" "env_tenant" {
  allow_organization_name_in_authentication_api = false
  # allowed_logout_urls = ["${local.env_seqtoid_org_url}/logout"]
  # default_audience
  # default_directory = "auth0"
  # default_redirection_uri = local.env_seqtoid_org_url
  enabled_locales = ["en"]
  # ephemeral_session_lifetime
  friendly_name = "Seqtoid ${var.env}"
  # idle_ephemeral_session_lifetime
  # idle_session_lifetime
  # phone_consolidated_experience
  picture_url = "${local.assets_url}/assets/logo-new.png"
  # sandbox_version         = "22"
  # session_lifetime        = 8760
  support_email = "seqtoid@ucsf.edu"
  # support_url             = "${local.env_seqtoid_org_url}/support"

  # error_page {
  #   html          = "<html></html>"
  #   show_log_link = false
  #   url           = "${local.env_seqtoid_org_url}/error"
  # }

  flags {
    # enable_custom_domain_in_emails         = true
    # enable_dynamic_client_registration     = false
    # enable_public_signup_user_exists_error = true
  }

  session_cookie {
    mode = "non-persistent"
  }

  # sessions {
  #   oidc_logout_prompt_enabled = false
  # }
  depends_on = [auth0_custom_domain_default.auth_env_seqtoid_org]
}

data "auth0_tenant" "env_tenant" {
  depends_on = [auth0_tenant.env_tenant]
}

resource "auth0_role" "admin" {
  name        = "Admin"
  description = "Administrator"
}

resource "auth0_client" "idseq_web" {
  name        = "idseq-web"
  description = "SeqtoID Web Application"
  allowed_clients = [
    # auth0_client.idseq_web_management.id
    # var.auth0_m2m_client_id,
    # local.env_seqtoid_org_url
  ]
  allowed_logout_urls = [
    local.env_seqtoid_org_url,
    # local.meta_env_seqtoid_org_url,
    "http://localhost:3000",
    # Preview sandboxes (dev only) -- see preview_sandbox_wildcard_url in locals.
    local.preview_sandbox_wildcard_url,
  ]
  allowed_origins = [
    local.env_seqtoid_org_url,
    # local.meta_env_seqtoid_org_url,
    "http://localhost:3000",
    local.preview_sandbox_wildcard_url,
  ]
  app_type = "regular_web"
  callbacks = [
    # "http://localhost:3000/auth/auth0/callback",
    # "http://127.0.0.2:4000/auth/auth0/callback",
    "${local.env_seqtoid_org_url}/auth/auth0/callback",
    "${local.env_seqtoid_org_url}/login",
    # "${local.meta_env_seqtoid_org_url}/auth/auth0/callback",
    # Preview sandboxes: pr-<N>.dev.seqtoid.org. The app derives redirect_uri from the request
    # host + OmniAuth's callback_path (/auth/auth0/callback, config/initializers/auth0.rb), and
    # the sandbox now serves on its own host (SERVER_DOMAIN, app 2e0fb6e2f) -- so login sent
    # pr-23.dev.seqtoid.org and Auth0 rejected it with "Callback URL mismatch".
    "${local.preview_sandbox_wildcard_url}/auth/auth0/callback",
    "${local.preview_sandbox_wildcard_url}/login",
  ]
  initiate_login_uri = "${local.env_seqtoid_org_url}/login"
  logo_uri           = "${local.assets_url}/assets/logo-new.png"
  sso                = true
  web_origins = [
    local.env_seqtoid_org_url,
    # local.meta_env_seqtoid_org_url,
    "http://localhost:3000",
  ]

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = 36000
    secret_encoded      = false
  }

  # refresh_token {
  #   rotation_type   = "non-rotating"
  #   expiration_type = "non-expiring"
  # }
}

resource "auth0_client_grant" "idseq_web_grant" {
  client_id    = auth0_client.idseq_web.id
  audience     = "https://${data.auth0_tenant.env_tenant.domain}/api/v2/" # TODO: Should be auth0_resource_server.idseq_web.identifier ??
  subject_type = "user"
  scopes       = []
}

resource "auth0_client" "idseq_web_management" {
  name     = "idseq-web-management"
  app_type = "non_interactive"
}

resource "auth0_client_grant" "idseq_web_management_grant" {
  client_id = auth0_client.idseq_web_management.id
  audience  = "https://${data.auth0_tenant.env_tenant.domain}/api/v2/"
  # subject_type = "client"
  scopes = [
    "read:users",
    "update:users",
    "delete:users",
    "create:users",
    "create:user_tickets",
    "read:roles",
  ]
}

resource "auth0_connection" "username_password_authentication" {
  name     = "Username-Password-Authentication"
  strategy = "auth0"
  # realms = [
  #   "Username-Password-Authentication"
  # ]

  options {
    import_mode                    = false
    disable_signup                 = true
    password_policy                = "excellent"
    strategy_version               = 2
    requires_username              = false
    brute_force_protection         = true
    enabled_database_customization = false

    mfa {
      active                 = true
      return_enroll_settings = true
    }

    password_history {
      size   = 5
      enable = true
    }

    password_dictionary {
      enable     = true
      dictionary = []
    }

    password_no_personal_info {
      enable = true
    }

    password_complexity_options {
      min_length = 10
    }
  }
}

resource "auth0_connection_client" "idseq_web_connection_client" {
  connection_id = auth0_connection.username_password_authentication.id
  client_id     = auth0_client.idseq_web.id
}

resource "auth0_connection_client" "idseq_web_management_connection_client" {
  connection_id = auth0_connection.username_password_authentication.id
  client_id     = auth0_client.idseq_web_management.id
}

# resource "auth0_branding" "seqtoid_branding" {
#   depends_on  = [auth0_custom_domain.auth_env_seqtoid_org]
#   logo_url    = "${local.assets_url}/assets/logo-new.png"
#   favicon_url = "${local.assets_url}/assets/CZID_Favicon_Black.png"
#
#   colors {
#     primary         = "#3867fa"
#     page_background = "#9a9996"
#   }
#
#   font {}
#
#   universal_login {
#     body = "<!DOCTYPE html><code><html><head>{%- auth0:head -%}</head><body>{%- auth0:widget -%}</body></html></code>"
#   }
# }

resource "auth0_prompt_custom_text" "login" {
  prompt   = "login"
  language = "en"

  body = jsonencode(
    {
      "login" : {
        "description" : "Log in to continue",
        # "logoAltText" : "SeqtoID",
        # "pageTitle" : "Log in | SeqtoID",
        "title" : "Welcome to SeqtoID",
      }
    }
  )
}

resource "auth0_prompt_custom_text" "login-password" {
  prompt   = "login-password"
  language = "en"

  body = jsonencode(
    {
      "login-password" : {
        "description" : "Enter your password",
        "title" : "Welcome to SeqtoID",
      }
    }
  )
}

resource "auth0_prompt_custom_text" "reset-password" {
  prompt   = "reset-password"
  language = "en"

  body = jsonencode(
    {
      "reset-password-request" = {
        "backToLoginLinkText" = "Back to Login"
      }
    }
  )
}

data "auth0_client" "idseq_web" {
  client_id = auth0_client.idseq_web.id
}

data "auth0_client" "idseq_web_management" {
  client_id = auth0_client.idseq_web_management.id
}

module "auth0-ssm-params" {
  source  = "../../../modules/aws-ssm-params-writer-v0.104.2" # cztack v0.104.2
  project = var.project
  env     = var.env
  service = "web"
  owner   = var.owner

  parameters = {
    AUTH0_CLIENT_ID     = auth0_client.idseq_web.client_id
    AUTH0_CLIENT_SECRET = data.auth0_client.idseq_web.client_secret
    AUTH0_CONNECTION    = auth0_connection.username_password_authentication.name
    # The CUSTOM domain, not the tenant domain. This is what is live in SSM (auth.dev.seqtoid.org,
    # v10) and what the app actually authenticates against; the config computed the tenant domain
    # instead, so a refreshed plan wanted to overwrite a working login setting with a different value.
    # It is also what upstream intended -- a2b4ff7: "Revert AUTH0_MANAGEMENT_DOMAIN to be the tenant
    # domain, instead of the custom DNS name. The AUTH0_DOMAIN is still the custom DNS name."
    # Config now matches reality, so the diff disappears and nothing changes in Auth0. See #695.
    AUTH0_DOMAIN                   = auth0_custom_domain.auth_env_seqtoid_org.domain
    AUTH0_MANAGEMENT_CLIENT_ID     = auth0_client.idseq_web_management.client_id
    AUTH0_MANAGEMENT_CLIENT_SECRET = data.auth0_client.idseq_web_management.client_secret
    # Deliberately the TENANT domain, NOT the custom one -- that is the whole point of a2b4ff7. The
    # old TODO here ("always the same as AUTH0_DOMAIN") is the assumption that commit reverted: the
    # Management API is addressed at the tenant domain even when logins use the custom domain.
    AUTH0_MANAGEMENT_DOMAIN = data.auth0_tenant.env_tenant.domain
  }
}
