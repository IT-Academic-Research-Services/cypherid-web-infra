module "elasticache_secure" {
  source                     = "../../../modules/aws-redis-replication-group-v0.104.2" # cztack v0.104.2
  at_rest_encryption_enabled = local.at_rest_encryption_enabled
  auth_token                 = local.auth_token
  description                = local.description
  engine_version             = local.engine_version
  ingress_security_group_ids = local.ingress_security_group_ids
  instance_type              = local.instance_type
  parameter_group_name       = local.parameter_group_name
  subnets                    = local.subnets
  tags                       = local.tags
  transit_encryption_enabled = local.transit_encryption_enabled
  vpc_id                     = local.vpc_id



}
