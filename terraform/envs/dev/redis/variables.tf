locals {
  ingress_security_group_ids = [data.terraform_remote_state.ecs.outputs.security_group_id]
  subnets                    = data.terraform_remote_state.cloud-env.outputs.private_subnets
  engine_version             = "7.1" # Upgraded as v5 is no longer supported
  parameter_group_name       = "default.redis7"
  instance_type              = "cache.m5.large"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  vpc_id                     = data.terraform_remote_state.cloud-env.outputs.vpc_id
  description                = "resque-secure"
  tags                       = var.tags # TODO: var.tags is deprecated
  auth_token                 = null
}
