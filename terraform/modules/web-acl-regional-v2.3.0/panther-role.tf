# # This role helps the Security Engineering team monitor the WebACL effectiveness
# module "panther-s3" {
#   count                                = var.enable_panther_ingest ? 1 : 0
#   source                               = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/panther-s3-ingest?ref=panther-s3-ingest-v1.0.0"
#   role_suffix                          = local.web_acl_name
#   s3_bucket_name                       = local.bucket_name
#   tags                                 = var.tags
#   managed_bucket_notifications_enabled = true
# }
