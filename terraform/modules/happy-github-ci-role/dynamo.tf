# module "dynamodb_writer" {
#   source    = "github.com/chanzuckerberg/cztack//aws-iam-policy-dynamodb-rw?ref=v0.92.0"
#   table_arn = var.dynamodb_table_arn
#   role_name = var.gh_actions_role_name
#   tags      = var.tags
# }
