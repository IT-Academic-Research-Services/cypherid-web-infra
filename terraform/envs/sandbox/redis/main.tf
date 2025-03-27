module "elasticache_secure" {
  source                        = "github.com/chanzuckerberg/cztack//aws-redis-replication-group?ref=v0.73.0"
  project                       = var.project
  env                           = var.env
  service                       = "resque-secure"
  owner                         = var.owner
  ingress_security_group_ids    = [data.terraform_remote_state.ecs.outputs.security_group_id]
  subnets                       = data.terraform_remote_state.cloud-env.outputs.private_subnets
  engine_version                = "5.0.3"
  parameter_group_name          = "default.redis5.0"
  instance_type                 = "cache.m5.large"
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  vpc_id                        = data.terraform_remote_state.cloud-env.outputs.vpc_id
  replication_group_description = "Secure redis group"
}
