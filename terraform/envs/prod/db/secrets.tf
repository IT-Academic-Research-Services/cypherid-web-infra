module "db_password" {
  source  = "../../../modules/aws-param-v0.26.1" # cztack v0.26.1
  project = var.project
  env     = var.env
  service = "web"
  name    = "db_password"
}
