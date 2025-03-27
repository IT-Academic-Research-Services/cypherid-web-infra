resource "auth0_client" "global" {
  name                 = "All Applications"
  custom_login_page    = file("${path.module}/pages/login.html")
  custom_login_page_on = true

  refresh_token {
    rotation_type   = "non-rotating"
    expiration_type = "non-expiring"
  }
}

resource "auth0_client" "idseq_web" {
  name = "idseq-web"
  allowed_clients = [
    "8t34lGa63vlDHNXglNWlWfh97WLaTdQt",
  ]
  allowed_logout_urls = [
    "http://localhost:3000/",
    "https://sandbox.idseq.net/",
    "https://meta.sandbox.idseq.net/",
    "http://sandbox.czid.org/",
    "https://sandbox.czid.org/",
  ]
  allowed_origins = [
    "http://localhost:3000",
    "https://sandbox.idseq.net",
    "https://meta.sandbox.idseq.net/",
    "https://sandbox.czid.org/",
  ]
  app_type = "regular_web"
  callbacks = [
    "http://localhost:3000/auth/auth0/callback",
    "http://127.0.0.2:4000/auth/auth0/callback",
    "https://sandbox.idseq.net/auth/auth0/callback",
    "https://meta.sandbox.idseq.net/auth/auth0/callback",
    "https://sandbox.czid.org/auth/auth0/callback",
  ]
  logo_uri = "https://assets.prod.czid.org/assets/CZID_Favicon_Black.png"
  sso      = true
  web_origins = [
    "http://localhost:3000",
    "https://sandbox.idseq.net",
    "https://meta.sandbox.idseq.net/",
    "https://sandbox.czid.org/",
  ]

  jwt_configuration {
    alg                 = "RS256"
    lifetime_in_seconds = 36000
    secret_encoded      = false
  }
}

resource "auth0_client" "auth0_deploy_cli_extension" {
  name     = "auth0-deploy-cli-extension"
  app_type = "non_interactive"
}

resource "auth0_client_grant" "auth0_deploy_cli_extension_grant" {
  client_id = auth0_client.auth0_deploy_cli_extension.id
  audience  = "https://czi-idseq-dev.auth0.com/api/v2/"
  scope = [
    "read:client_grants",
    "create:client_grants",
    "delete:client_grants",
    "update:client_grants",
    "read:users",
    "update:users",
    "delete:users",
    "create:users",
    "read:users_app_metadata",
    "update:users_app_metadata",
    "delete:users_app_metadata",
    "create:users_app_metadata",
    "create:user_tickets",
    "read:clients",
    "update:clients",
    "delete:clients",
    "create:clients",
    "read:client_keys",
    "update:client_keys",
    "delete:client_keys",
    "create:client_keys",
    "read:connections",
    "update:connections",
    "delete:connections",
    "create:connections",
    "read:resource_servers",
    "update:resource_servers",
    "delete:resource_servers",
    "create:resource_servers",
    "read:device_credentials",
    "update:device_credentials",
    "delete:device_credentials",
    "create:device_credentials",
    "read:rules",
    "update:rules",
    "delete:rules",
    "create:rules",
    "read:rules_configs",
    "update:rules_configs",
    "delete:rules_configs",
    "read:hooks",
    "read:email_provider",
    "update:email_provider",
    "delete:email_provider",
    "create:email_provider",
    "blacklist:tokens",
    "read:stats",
    "read:tenant_settings",
    "update:tenant_settings",
    "read:logs",
    "read:shields",
    "create:shields",
    "delete:shields",
    "read:anomaly_blocks",
    "delete:anomaly_blocks",
    "update:triggers",
    "read:triggers",
    "read:grants",
    "delete:grants",
    "read:guardian_factors",
    "update:guardian_factors",
    "read:guardian_enrollments",
    "delete:guardian_enrollments",
    "create:guardian_enrollment_tickets",
    "read:user_idp_tokens",
    "create:passwords_checking_job",
    "delete:passwords_checking_job",
    "read:custom_domains",
    "delete:custom_domains",
    "create:custom_domains",
    "read:email_templates",
    "create:email_templates",
    "update:email_templates",
    "read:mfa_policies",
    "update:mfa_policies",
    "read:roles",
    "create:roles",
    "delete:roles",
    "update:roles",
    "read:prompts",
    "update:prompts",
    "read:branding",
    "update:branding",
    "delete:branding",
  ]
}

resource "auth0_client_grant" "idseq_web_grant" {
  client_id = auth0_client.idseq_web.id
  audience  = "https://sandbox.idseq.net"
  scope     = []
}

resource "auth0_client" "idseq_web_management" {
  name     = "idseq-web-management"
  app_type = "non_interactive"
}

resource "auth0_client_grant" "idseq_web_management_grant" {
  client_id = auth0_client.idseq_web_management.id
  audience  = "https://czi-idseq-dev.auth0.com/api/v2/"
  scope = [
    "read:users",
    "update:users",
    "delete:users",
    "create:users",
    "create:user_tickets",
    "read:roles",
  ]
}

resource "auth0_client" "idseq_cli_v2" {
  name = "idseq-cli-v2"
  allowed_clients = [
    "JuxupFFHWAkv6g3IBYKe5fGBNTOAXNOV",
    "https://sandbox.idseq.net",
  ]
  app_type = "native"
}

resource "auth0_branding" "brand" {
  logo_url = "https://assets.prod.czid.org/assets/CZID_Logo_Black.png"

  colors {
    primary         = "#3867fa"
    page_background = "#FFFFFF"
  }

  font {}

  universal_login {
    body = "<!DOCTYPE html><code><html><head>{%- auth0:head -%}</head><body>{%- auth0:widget -%}</body></html></code>"
  }
}

resource "auth0_connection" "idseq_legacy_users" {
  name     = "idseq-legacy-users"
  strategy = "auth0"
  enabled_clients = [
    auth0_client.idseq_web_management.id,
    auth0_client.auth0_deploy_cli_extension.id,
  ]
  is_domain_connection = false
  realms = [
    "idseq-legacy-users",
  ]

  options {
    import_mode                    = false
    disable_signup                 = true
    password_policy                = "good"
    strategy_version               = 2
    requires_username              = true
    brute_force_protection         = true
    enabled_database_customization = false

    mfa {
      active                 = true
      return_enroll_settings = true
    }

    validation {
      username {
        max = 15
        min = 1
      }
    }

    password_complexity_options {
      min_length = 1
    }
  }
}

resource "auth0_connection" "username_password_authentication" {
  name     = "Username-Password-Authentication"
  strategy = "auth0"
  enabled_clients = [
    auth0_client.idseq_web.id,
    auth0_client.auth0_deploy_cli_extension.id,
    auth0_client.idseq_web_management.id,
    auth0_client.idseq_cli_v2.id,
  ]
  is_domain_connection = false
  realms = [
    "Username-Password-Authentication",
  ]

  options {
    import_mode                    = true
    disable_signup                 = false
    password_policy                = "excellent"
    strategy_version               = 2
    requires_username              = false
    brute_force_protection         = true
    enabled_database_customization = true

    custom_scripts = {
      login    = file("${path.module}/scripts/login.js")
      get_user = file("${path.module}/scripts/get_user.js")
    }

    # NOTE: these are encrypted
    configuration = {
      AUTH0_DOMAIN        = "2.0$a0858bad153334eb92b46ce05a2db540f4b72b4454cb74987243e8b71d761109$cbf4802839e101bfeeb45f98ee4b3024$d15a324e911abfda189b602c225aa2e97e08e91490a37a572eba90c94b4ea0aa"
      AUTH0_CLIENT_ID     = "2.0$d8cddf649696a644b2b19b2d96134668d7eb7a11156a9be9c639b6ad8bba13f5be7ce658b19ced3e9c9b1cf2bef5a28a$696d1b60d64269282ef652640793775d$6a534d7507b6b247a36ecdc29f9fced586fc1512a64e551dadf7221b67689ca3"
      AUTH0_CLIENT_SECRET = "2.0$b07097368044e7d291ea2fb7e91da6544302c2a524cd1ad37bcd26a41094a59d71fc20ce5089a8e0f4700ee652e9eaa01363781f75a62edd06bd43b7920afd45ae1556d3444b3144bf3a01a62e88e81b$8da7b827cd86cfb5bc2094f57da41fd3$c949fe3320a2c7e128f449250291aef099e71c673ec121e769fed25efe2d4f90"
    }

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