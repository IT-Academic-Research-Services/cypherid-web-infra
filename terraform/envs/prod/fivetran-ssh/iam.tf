module "policy-params-service" {
  source    = "../../../modules/aws-params-reader-policy-v0.41.0" # cztack v0.41.0
  env       = var.env
  project   = var.project
  region    = var.region
  role_name = module.ecs-role.name

  service = var.component
}

module "ecs-role" {
  source  = "../../../modules/aws-iam-ecs-task-role-v0.41.0" # cztack v0.41.0
  project = var.project
  env     = var.env
  owner   = var.owner

  service = var.component
}
