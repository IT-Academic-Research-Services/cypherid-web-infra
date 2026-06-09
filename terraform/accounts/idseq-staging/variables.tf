locals {
  attributes = ["state"]
  # billing_mode                = "PAY_PER_REQUEST"
  dynamodb_enabled = var.dynamodb_enabled
  environment      = "staging"
  name             = "${var.project}-infra-${local.environment}"
  namespace        = "${var.tags.project}-${local.environment}-${var.tags.service}"
  s3_bucket_name   = var.s3_bucket_name
  # prevent_unencrypted_uploads = var.prevent_unencrypted_uploads
  stage             = var.env
  tags              = var.tags # TODO: var.tags is deprecated
  terraform_version = "1.3.6"
}
