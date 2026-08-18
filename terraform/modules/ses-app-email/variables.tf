# Reusable SES setup for the app's transactional mail (support -> ServiceNow, plus the
# existing UserMailer/ComplianceMailer). One module, called per env from a thin leaf, so dev
# and env-staging are true mirrors (env parity) -- only the calling leaf's terraform.tf differs.

variable "env_fqdn" {
  type        = string
  description = "The env's seqtoid.org subdomain, used as the SES sending domain identity (e.g. dev.seqtoid.org, staging.seqtoid.org). Sourced from the route53 remote-state output env_seqtoid_org_fqdn."
}

variable "zone_id" {
  type        = string
  description = "Route53 hosted-zone id for env_fqdn (route53 remote-state output env_seqtoid_org_zone_id). DKIM/MAIL FROM/DMARC records are written here."
}

variable "region" {
  type        = string
  default     = "us-west-2"
  description = "SES region. The app's SMTP endpoint + feedback-smtp MAIL FROM MX are region-specific."
}

variable "from_local_part" {
  type        = string
  default     = "no-reply"
  description = "Local part of the verified From address: <from_local_part>@<env_fqdn>. SES can only send from this verified identity -- NOT from seqtoid-support@ucsf.edu."
}

variable "mail_from_subdomain" {
  type        = string
  default     = "mail"
  description = "Custom MAIL FROM subdomain for SPF alignment: <mail_from_subdomain>.<env_fqdn>."
}

variable "support_inbox_email" {
  type        = string
  description = "The ServiceNow inbound address a support report is emailed to (seqtoid-support@ucsf.edu). Used for the DMARC rua and, when verify_support_recipient is true, verified as a recipient so SES can send to it while in sandbox."
}

variable "verify_support_recipient" {
  type        = bool
  default     = true
  description = "Create an SES email-address identity for support_inbox_email. In the SES sandbox this is REQUIRED to send to that address; applying it makes SES send a verification link to that mailbox (someone must click it). Set false once the account has SES production access."
}

# --- Optional chamber wiring (off by default) ------------------------------------------
# When chamber_ssm_prefix is set, the module writes the app's mail env vars as SSM params at
# that path so `chamber exec` picks them up. Left "" by default so this PR provisions SES
# only and does not depend on the exact chamber path being confirmed -- the creds/addresses
# are exposed as outputs to wire by hand or in a follow-up. See the module README.
variable "chamber_ssm_prefix" {
  type        = string
  default     = ""
  description = "SSM path prefix the app's chamber service reads (e.g. /idseq-dev-web/). When non-empty, SMTP_USER/SMTP_PASSWORD/MAIL_FROM_ADDRESS/SUPPORT_INBOX_EMAIL (and the two below when set) are written there."
}

variable "support_log_group" {
  type        = string
  default     = ""
  description = "SUPPORT_LOG_GROUP: the CloudWatch log group the support deep-links query. Written to chamber only when both this and chamber_ssm_prefix are set."
}

variable "otel_dashboard_base_url" {
  type        = string
  default     = ""
  description = "OTEL_DASHBOARD_BASE_URL: the Grafana Support Inbox base URL the support deep-links point at. Written to chamber only when both this and chamber_ssm_prefix are set."
}

variable "tags" {
  type    = map(string)
  default = {}
}
