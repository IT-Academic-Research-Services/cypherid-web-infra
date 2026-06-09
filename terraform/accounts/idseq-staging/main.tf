module "terraform-aws-tfstate-backend" {
  source     = "git@github.com:cloudposse/terraform-aws-tfstate-backend?ref=1.4.0"
  attributes = local.attributes
  # billing_mode                = local.billing_mode
  dynamodb_enabled = local.dynamodb_enabled
  # environment                 = local.environment
  # name                        = local.name
  # namespace                   = local.namespace
  s3_bucket_name = local.s3_bucket_name
  # prevent_unencrypted_uploads = local.prevent_unencrypted_uploads
  # stage                       = local.stage
  tags              = local.tags
  terraform_version = local.terraform_version
}
