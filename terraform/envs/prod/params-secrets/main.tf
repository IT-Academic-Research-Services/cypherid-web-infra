module "aws-params-secrets-setup" {
  source     = "../../../modules/aws-params-secrets-setup-v0.104.2" # cztack v0.104.2
  alias_name = local.alias_name
  env        = local.env
  owner      = local.owner
  project    = local.project
  service    = local.service



}
