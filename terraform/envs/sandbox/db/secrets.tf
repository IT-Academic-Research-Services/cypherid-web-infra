module "db_password" {
  source  = "git@github.com:chanzuckerberg/cztack//aws-param?ref=v0.26.1"
  project = var.project
  env     = var.env
  service = "web"
  name    = "db_password"
}
