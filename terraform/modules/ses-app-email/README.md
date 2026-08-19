# ses-app-email

SES setup for the app's transactional mail: the in-app support report -> ServiceNow inbox
chain (see seqtoid-web `SupportRequestMailer` / `SupportRouter#servicenow_email_sink`), plus
the existing `UserMailer` / `ComplianceMailer`, which never delivered because no SES sending
identity (or send grant) was provisioned.

One module, called from a thin per-env leaf (`envs/dev/email`, `envs/staging/email`) so dev
and env-staging are mirrors -- only the leaf's `terraform.tf` (account / profile / backend)
differs. The sending domain is the env's own seqtoid.org subdomain (`dev.seqtoid.org`,
`staging.seqtoid.org`), sourced from the route53 remote state -- **not** the apex
`seqtoid.org` (that zone lives in the CZI account).

## What it creates
- SES v2 sending-domain identity for `<env>.seqtoid.org` + Easy-DKIM, with the 3 DKIM CNAMEs.
- Custom MAIL FROM (`mail.<env>.seqtoid.org`) + its MX/SPF records, and a `p=none` DMARC record.
- An SES email-identity for the support inbox (`seqtoid-support@ucsf.edu`) so SES can deliver
  to it **while in the sandbox** -- see "Sandbox" below.
- Optional chamber SSM params (`MAIL_FROM_ADDRESS` / `SUPPORT_INBOX_EMAIL` / `SUPPORT_LOG_GROUP`
  / `OTEL_DASHBOARD_BASE_URL`, SecureString under the chamber CMK) when `chamber_ssm_prefix` is set.

This module creates **no IAM user and no SMTP access key**. The app sends via ActionMailer
`:sesv2` (the SESv2 SendEmail API) authenticating with the **seqtoid-web pod's IRSA role** -- the
AWS default credential chain resolves to that role in-pod. The `ses:SendEmail`/`SendRawEmail`
grant lives on the web IRSA role in the web component, scoped to this domain identity + a
`no-reply@<env>.seqtoid.org` From address:
- dev: `terraform/envs/dev/web/eks-irsa-ses.tf` (on `aws_iam_role.seqtoid_web_eks`).
- staging / sandbox / prod-preview: the reconstitute web IRSA role in `seqtoid-ssot-infra`
  (`infra/state-foundation/app`), which already carries the SES send grant.

Switching from an IAM SMTP user to IRSA also removes the checkov CKV_AWS_273 long-lived
access-key finding, and means the CI apply role never needs `iam:CreateUser`.

## Manual steps after apply (not automatable)
1. **Verify the recipient (sandbox).** Apply sends a verification link to
   `seqtoid-support@ucsf.edu`; someone must click it before SES will deliver there. (Or request
   SES production access and set `verify_support_recipient = false`.)
2. **Set the app's chamber vars.** Either set `chamber_ssm_prefix` (e.g. `/idseq-dev-web/`) so
   this module writes them, or set by hand from the outputs:
   - `MAIL_FROM_ADDRESS` = `from_address` output
   - `SUPPORT_INBOX_EMAIL` = `seqtoid-support@ucsf.edu`
   - `SUPPORT_LOG_GROUP` + `OTEL_DASHBOARD_BASE_URL` -- **still TODO**: the app builds the
     support deep-links from these (they're `TODO-set-...` placeholders today). Set them to the
     CloudWatch app log group and the Grafana Support Inbox base URL so the links resolve.
   No `SMTP_USER`/`SMTP_PASSWORD` -- the app uses its IRSA role, not SMTP creds.

## Deploy order / env-staging freeze
Apply **dev first**, prove a ServiceNow ticket spawns end to end, then env-staging. env-staging
is under a code freeze -- authored here but **held**; apply needs a per-fix freeze exception.
