# module "db_password" {
#   source  = "git@github.com:chanzuckerberg/cztack//aws-param?ref=v0.26.1"
#   project = var.project
#   env     = var.env
#   service = "web"
#   name    = "db_password"
# }

locals {
  rotate_version = "1" // Increment this to rotate the secret
}

ephemeral "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_lower = 1
  min_upper = 1
  min_numeric = 1
  min_special = 1
}

//This could be a secret in Secrets Manager instead of SSM parameter store. That includes built-in rotation, but also costs money whereas SSM parameter store is free.
//TDB if UCSF has a preference
resource "aws_ssm_parameter" "db_master_password" {
  name        = "${local.ssm_param_name}_password"
  description = "RDS DB password for ${var.env} MySQL DB supporting web app"
  type        = "SecureString"
  value_wo    = ephemeral.random_password.db_password.result
  value_wo_version = local.rotate_version
}