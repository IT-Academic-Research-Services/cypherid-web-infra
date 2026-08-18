# SES for the app's transactional mail (in-app support -> ServiceNow inbox, plus the existing
# UserMailer/ComplianceMailer). All logic lives in the shared module so dev and env-staging are
# mirrors; only terraform.tf (account/profile/backend) differs between them.
module "email" {
  source = "../../../modules/ses-app-email"

  env_fqdn = data.terraform_remote_state.route53.outputs.env_seqtoid_org_fqdn
  zone_id  = data.terraform_remote_state.route53.outputs.env_seqtoid_org_zone_id

  support_inbox_email     = var.support_inbox_email
  chamber_ssm_prefix      = var.chamber_ssm_prefix
  support_log_group       = var.support_log_group
  otel_dashboard_base_url = var.otel_dashboard_base_url

  tags = var.tags
}
