# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.

module "aws-elb-access-logs-bucket" {
  source        = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/aws-elb-access-logs-bucket?ref=v0.420.0"
  bucket_policy = local.bucket_policy
  env           = local.env
  owner         = local.owner
  project       = local.project
  service       = local.service



}
