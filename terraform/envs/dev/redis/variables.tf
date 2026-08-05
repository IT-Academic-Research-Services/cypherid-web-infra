locals {
  ingress_security_group_ids = [data.terraform_remote_state.ecs.outputs.security_group_id]
  subnets                    = data.terraform_remote_state.cloud-env.outputs.private_subnets
  engine_version             = "7.1" # Upgraded as v5 is no longer supported
  parameter_group_name       = "default.redis7"
  instance_type              = "cache.t4g.small"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  vpc_id                     = data.terraform_remote_state.cloud-env.outputs.vpc_id
  description                = "resque-secure"
  tags                       = var.tags # TODO: var.tags is deprecated
  auth_token                 = null
  # Backup. Found 2026-08-05 at SnapshotRetentionLimit=0 (the AWS default) -- i.e. NO recovery point
  # for Redis in this environment, matching what was found in every other env. Redis is not purely a
  # cache here: it backs the Rails cache store AND the Resque job queues, so a loss drops queued and
  # in-flight pipeline work. 7 days matches the Aurora window and env-staging.
  # cache.t4g.small supports snapshots (only t1.micro / t2.* do not). Window sits off the maintenance
  # window and matches the one AWS had already assigned to this group.
  snapshot_retention_limit = 7
  snapshot_window          = "08:00-09:00"
}
