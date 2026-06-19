locals {
  account_id                  = var.aws_accounts.idseq-dev
  env                         = var.env
  s3_bucket_idseq_bench       = var.s3_bucket_idseq_bench
  s3_bucket_public_references = var.s3_bucket_public_references
  s3_bucket_samples           = var.s3_bucket_samples
  s3_bucket_workflows         = data.terraform_remote_state.web.outputs.s3_bucket_workflows
  tags                        = var.tags
}
