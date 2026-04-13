# NOTE: The following ENV Variables MUST be set, and must point to the machine-to-machine (m2m) Auth0 Application
#     AUTH0_CLIENT_ID
#     AUTH0_CLIENT_SECRET

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
  env_seqtoid_org_fqdn     = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  env_seqtoid_org_url      = "https://${local.env_seqtoid_org_fqdn}"
  meta_env_seqtoid_org_url = "https://meta.${local.env_seqtoid_org_fqdn}"
  assets_fqdn              = data.terraform_remote_state.web.outputs.assets_fqdn
}

resource "auth0_role" "admin" {
  name        = "Admin"
  description = "Administrator"
}

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

# resource "auth0_client" "idseq_cli_v2" {
#   name = "idseq-cli-v2"
#   allowed_clients = [
#     "JuxupFFHWAkv6g3IBYKe5fGBNTOAXNOV",
#     "https://sandbox.idseq.net",
#     or
#     var.auth0_m2m_client_id,
#       local.env_seqtoid_org_url,
#   ]
#   app_type = "native"
# }
#

# resource "auth0_connection" "idseq_legacy_users" {
#   name     = "idseq-legacy-users"
#   strategy = "auth0"
#   enabled_clients = [
#     auth0_client.idseq_web_management.id,
#     auth0_client.auth0_deploy_cli_extension.id,
#     or
#     auth0_m2m_client_id,
#   ]
#   is_domain_connection = false
#   realms = [
#     "idseq-legacy-users",
#   ]
#
#   options {
#     import_mode                    = false
#     disable_signup                 = true
#     password_policy                = "good"
#     strategy_version               = 2
#     requires_username              = true
#     brute_force_protection         = true
#     enabled_database_customization = false
#
#     mfa {
#       active                 = true
#       return_enroll_settings = true
#     }
#
#     validation {
#       username {
#         max = 15
#         min = 1
#       }
#     }
#
#     password_complexity_options {
#       min_length = 1
#     }
#   }
# }

# resource "auth0_custom_domain" "env_seqtoid_org" {
#   domain     = "auth.sequtoid.com"
#   type       = "auth0_managed_certs"
#   tls_policy = "recommended"
#   # domain_metadata = {
#   #   key1 : "value1"
#   #   key2 : "value2"
#   # }
# }
#
# resource "auth0_organization" "seqtoid_org" {
#   name         = "seqtoid"
#   display_name = "Seqtoid Org"
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
# resource "auth0_organization_connection" "seqtoid_org_connection" {
#   organization_id            = auth0_organization.seqtoid_org.id
#   connection_id              = auth0_connection.username_password_authentication.id
#   assign_membership_on_login = true
#   is_signup_enabled          = false
#   # show_as_button             = true
# }

resource "auth0_branding" "seqtoid_branding" {
  # depends_on  = [auth0_custom_domain.env_seqtoid_org]
  logo_url    = "https://${local.assets_fqdn}/assets/logo-new.png"
  favicon_url = "https://${local.assets_fqdn}/assets/CZID_Favicon_Black.png"

  colors {
    primary         = "#3867fa"
    page_background = "#9a9996"
  }

  # font {}

  # universal_login {
  #   body = "<!DOCTYPE html><code><html><head>{%- auth0:head -%}</head><body>{%- auth0:widget -%}</body></html></code>"
  # }
}

resource "auth0_prompt_custom_text" "seqtoid_login" {
  prompt   = "login"
  language = "en"

  body = jsonencode(
    {
      "login" : {
        "description" : "Log in to continue",
        # "logoAltText" : "SeqtoID [Dev]",
        # "pageTitle" : "Log in | SeqtoID [Dev]",
        "title" : "Welcome to SeqtoID [Dev]",
      }
    }
  )
}

resource "auth0_prompt_custom_text" "seqtoid_signup" {
  prompt   = "signup"
  language = "en"

  body = jsonencode(
    {
      "signup" : {
        "description" : "Sign Up to continue",
        "title" : "Welcome to SeqtoID [Dev]",
      }
    }
  )
}

resource "auth0_connection" "username_password_authentication" {
  name                 = "Username-Password-Authentication"
  strategy             = "auth0"
  is_domain_connection = false
  realms = [
    "Username-Password-Authentication",
  ]

  options {
    import_mode                    = false # TODO: true when we can use a custom user DB?
    disable_signup                 = false
    password_policy                = "excellent"
    strategy_version               = 2
    requires_username              = false
    brute_force_protection         = true
    enabled_database_customization = false # TODO: true when we can use a custom user DB

    # custom_scripts = {
    #   login    = file("${path.module}/scripts/login.js")
    #   get_user = file("${path.module}/scripts/get_user.js")
    # }
    #
    # # NOTE: these are encrypted
    # configuration = {
    #   AUTH0_DOMAIN        = var.auth0_m2m_domain
    #   AUTH0_CLIENT_ID     = auth0_client.idseq_web.client_id
    #   AUTH0_CLIENT_SECRET = auth0_client.idseq_web.client_secret
    # }

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
