# You cannot create a new backend by simply defining this and then
# immediately proceeding to "terraform apply". The S3 backend must
# be bootstrapped according to the simple yet essential procedure in
# https://github.com/cloudposse/terraform-aws-tfstate-backend#usage
module "terraform-aws-tfstate-backend" {
  source     = "git@github.com:cloudposse/terraform-aws-tfstate-backend?ref=v1.7.1"
  attributes = local.attributes
  # billing_mode                = local.billing_mode
  dynamodb_enabled = local.dynamodb_enabled
  environment      = local.environment
  # force_destroy               = local.force_destroy
  logging   = local.logging
  name      = local.name
  namespace = local.namespace
  # prevent_unencrypted_uploads = local.prevent_unencrypted_uploads
  profile               = local.profile
  s3_bucket_name        = local.s3_bucket_name
  s3_state_lock_enabled = local.s3_state_lock_enabled
  stage                 = local.stage
  # tags                        = local.tags
  terraform_version = local.terraform_version
  # terraform_state_file        = local.terraform_state_file
}
