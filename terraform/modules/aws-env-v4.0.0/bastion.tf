#Commented out as bastions are no longer needed
# locals {
#   default_bastion_instance_type = "t3.medium"
# }

# module "bastion" {
#   source                       = "../../modules/bastion"
#   count                        = (var.bastion_config != null) ? 1 : 0
#   project                      = var.project
#   env                          = var.env
#   region                       = var.region
#   vpc_id                       = module.vpc.vpc_id
#   ssh_key_name                 = var.bastion_config.ssh_key_name
#   route53_zone_id              = var.bastion_config.zone_id
#   subdomain                    = coalesce(var.bastion_config.subdomain, "bastion-${var.env}")
#   public_subnets               = module.vpc.public_subnets
#   private_subnets              = module.vpc.private_subnets
#   owner                        = var.owner
#   bastion_ssh_users            = var.bastion_config.ssh_users
#   datadog_api_key              = var.datadog_api_key
#   allowed_ingress_cidr_blocks  = var.bastion_config.allowed_cidr_blocks.ingress
#   allowed_egress_cidr_blocks   = var.bastion_config.allowed_cidr_blocks.egress
#   disable_auto_security_update = var.bastion_config.czi_security_update
#   instance_type = coalesce(
#     var.bastion_config.instance_type,
#     local.default_bastion_instance_type,
#   )
#   ebs_volume_type = var.bastion_config.ebs_volume_type
# }
