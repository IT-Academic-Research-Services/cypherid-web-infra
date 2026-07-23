# Let the web app (seqtoid-web IRSA role) submit bulk-download tar jobs to AWS Batch, replacing
# the aegea -> ECS-Fargate launcher (Forgejo #846 / SMP-1477; Sentry DEV-RAILS-PROJECT-25).
#
# Pairs with terraform/envs/dev/batch/bulk-download.tf (the job definition + job role live in the
# `batch` component). ARNs are constructed by convention rather than via remote state to keep this
# a clean, self-contained targeted-apply on the `web` component.
#
# Apply (reviewer-gated): targeted-apply on component `web` for
#   aws_iam_role_policy.seqtoid_web_bulk_download

data "aws_caller_identity" "bulk_download" {}
data "aws_region" "bulk_download" {}

locals {
  bd_account  = data.aws_caller_identity.bulk_download.account_id
  bd_region   = data.aws_region.bulk_download.name
  bd_job_def  = "arn:aws:batch:${local.bd_region}:${local.bd_account}:job-definition/seqtoid-web-${var.env}-bulk-download"
  bd_queue    = "arn:aws:batch:${local.bd_region}:${local.bd_account}:job-queue/idseq-${var.env}-lomem"
  bd_job_role = "arn:aws:iam::${local.bd_account}:role/seqtoid-web-${var.env}-bulk-download-job"
}

data "aws_iam_policy_document" "seqtoid_web_bulk_download" {
  # checkov:skip=CKV_AWS_356:batch:DescribeJobs has no resource-level support in IAM (must be "*"); the
  # only other unscoped action is TerminateJob, which is addressed by runtime job id. SubmitJob + PassRole are fully scoped.
  # checkov:skip=CKV_AWS_111:Same rationale -- DescribeJobs/TerminateJob cannot be ARN-constrained; all write-capable grants (SubmitJob, PassRole) are scoped.
  statement {
    sid       = "SubmitBulkDownloadJobs"
    actions   = ["batch:SubmitJob"]
    resources = [local.bd_job_def, "${local.bd_job_def}:*", local.bd_queue]
  }
  statement {
    # DescribeJobs does not support resource-level scoping; TerminateJob is by runtime job id.
    sid       = "TrackBulkDownloadJobs"
    actions   = ["batch:DescribeJobs", "batch:TerminateJob"]
    resources = ["*"]
  }
  statement {
    sid       = "PassBulkDownloadJobRole"
    actions   = ["iam:PassRole"]
    resources = [local.bd_job_role]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_bulk_download" {
  name   = "seqtoid-web-${var.env}-bulk-download"
  role   = aws_iam_role.seqtoid_web_eks.id
  policy = data.aws_iam_policy_document.seqtoid_web_bulk_download.json
}
