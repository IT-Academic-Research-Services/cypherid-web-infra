module "policy-params-service" {
  source    = "github.com/chanzuckerberg/cztack//aws-params-reader-policy?ref=v0.41.0"
  env       = var.env
  project   = var.project
  region    = var.region
  role_name = module.ecs-role.name

  service = var.component
}

module "ecs-role" {
  source  = "github.com/chanzuckerberg/cztack//aws-iam-ecs-task-role?ref=v0.41.0"
  project = var.project
  env     = var.env
  owner   = var.owner

  service = var.component
}
