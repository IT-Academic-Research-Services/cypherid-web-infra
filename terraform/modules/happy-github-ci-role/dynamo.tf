module "dynamodb_writer" {
  source    = "../aws-iam-policy-dynamodb-rw-v0.104.2" # cztack v0.104.2
  table_arn = var.dynamodb_table_arn
  role_name = var.gh_actions_role_name
  tags      = var.tags
}
