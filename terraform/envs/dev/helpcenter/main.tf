module "static_site" {
  source = "../../../modules/static-site"

  env     = var.env
  service = var.component
  domain  = "helpcenter.dev.seqtoid.org"

  zone_id                    = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id
  web_acl_id                 = data.terraform_remote_state.web.outputs.cloudfront_web_acl_id
  log_bucket_domain_name     = data.terraform_remote_state.web.outputs.cloudfront_access_logs_bucket_domain_name
  s3_log_bucket_name         = data.terraform_remote_state.web.outputs.cloudfront_access_logs_bucket_name
  response_headers_policy_id = data.terraform_remote_state.web.outputs.cloudfront_response_headers_policy_id
  log_prefix                 = "helpcenter/"

  # Serve per-directory index files: /articles/<slug>/ -> /articles/<slug>/index.html.
  # web-assets deliberately leaves this off (default false).
  enable_index_rewrite = true

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
