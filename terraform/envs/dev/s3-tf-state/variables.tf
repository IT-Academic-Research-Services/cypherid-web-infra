locals {
  attributes             = ["state"]
  billing_mode           = "PAY_PER_REQUEST"
  environment            = var.tags.env
  logging_bucket_enabled = true
  name                   = "idseq-infra-nonprod"
  namespace              = "${var.tags.project}-${var.tags.env}-${var.tags.service}"
  stage                  = var.tags.env
  tags                   = var.tags
  terraform_version      = "1.3.6"
}