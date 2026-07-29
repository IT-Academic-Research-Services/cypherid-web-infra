# Dev runs these five workloads as Kubernetes pods (EKS/Argo); the dev ECS cluster was torn down at
# the migration. Terraform still declared the ECS services, so a REFRESHED plan wanted to re-create
# all five -- duplicating workloads already running on EKS. create_service = false keeps the task
# definitions (still referenced) while creating no ECS service. staging/prod/sandbox are unaffected:
# the module defaults create_service = true. See platform-overhaul #687.

module "resque" {
  source        = "../../../modules/aws-ecs-job-v0.104.2" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
  create_service         = false
}

module "resque-pipeline-monitor" {
  source        = "../../../modules/aws-ecs-job-v0.104.2" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-pipeline-monitor"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
  create_service         = false
}

module "resque-result-monitor" {
  source        = "../../../modules/aws-ecs-job-v0.104.2" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-result-monitor"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
  create_service         = false
}

module "resque-scheduler" {
  source        = "../../../modules/aws-ecs-job-v0.104.2" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "resque-scheduler"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
  create_service         = false
}

module "shoryuken" {
  source        = "../../../modules/aws-ecs-job-v0.104.2" # cztack v0.104.2
  desired_count = 1
  env           = var.env
  service       = "shoryuken"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
  create_service         = false
}
