# =============================================================================
# SES send grant for the seqtoid-web pod (IRSA).
#
# The app sends transactional mail (support -> ServiceNow, UserMailer, ComplianceMailer)
# via ActionMailer :sesv2 -- the SESv2 SendEmail API -- authenticating with THIS pod's IRSA
# role (aws_iam_role.seqtoid_web_eks). The AWS default credential chain resolves to the IRSA
# role in-pod, so there is no SMTP IAM user and no long-lived access key (the ses-app-email
# module used to create one; that piece is removed).
#
# Least privilege: ses:SendEmail / ses:SendRawEmail from the env's OWN SES sending-domain
# identity ONLY (dev.seqtoid.org, created by the email component's ses-app-email module), and
# only with a From address of no-reply@<env_fqdn> -- the module's verified From identity.
#
# ADDITIVE: a 3rd inline policy on the existing seqtoid_web_eks role. The CI apply role already
# manages this role's inline policies, so this applies cleanly (no iam:CreateUser needed).
# =============================================================================

data "aws_iam_policy_document" "seqtoid_web_eks_ses" {
  statement {
    sid       = "SendFromVerifiedDomainIdentityOnly"
    effect    = "Allow"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:identity/${local.env_fqdn}"]
    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = ["no-reply@${local.env_fqdn}"]
    }
  }
}

resource "aws_iam_role_policy" "seqtoid_web_eks_ses" {
  name   = "seqtoid-web-${var.env}-ses"
  role   = aws_iam_role.seqtoid_web_eks.id
  policy = data.aws_iam_policy_document.seqtoid_web_eks_ses.json
}
