locals {
  attributes       = ["state"]
  dynamodb_enabled = false
  environment      = "prod"
  logging = [{
    target_bucket = var.s3_bucket_name
    target_prefix = "tfstate.log"
  }]
  name                  = "${var.project}-infra-${local.environment}"
  namespace             = "${var.project}-${local.environment}" # "${var.project}-${local.environment}-${var.tags.service}"
  profile               = var.aws_profile
  s3_bucket_name        = var.s3_bucket_name
  s3_state_lock_enabled = true
  stage                 = var.env
  # tags                  = var.tags # TODO: var.tags is deprecated
  terraform_version = "1.14.3"
  version           = "v1.7.1"
}
