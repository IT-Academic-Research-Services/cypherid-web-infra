module "resque" {
  source        = "../../../modules/aws-ecs-job-v0.41.0" # cztack v0.41.0
  desired_count = 2
  env           = var.env
  service       = "resque"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}

module "resque-scheduler" {
  source        = "../../../modules/aws-ecs-job-v0.41.0" # cztack v0.41.0
  desired_count = 1
  env           = var.env
  service       = "resque-scheduler"
  project       = var.project
  owner         = var.owner
  cluster_id    = data.terraform_remote_state.ecs.outputs.cluster_id
  task_role_arn = data.terraform_remote_state.web.outputs.task_role_arn

  manage_task_definition = false
}
