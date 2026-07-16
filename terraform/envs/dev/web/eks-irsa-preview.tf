# =============================================================================
# Per-PR PREVIEW sandbox IRSA role -- seqtoid-web-preview (#618/#619).
#
# One shared role assumed by the seqtoid-web ServiceAccount in ANY per-PR namespace
# (seqtoid-pr-*) on czid-dev-eks-v2. It is deliberately SEPARATE from and TIGHTER
# than the dev role (seqtoid-web-dev, eks-irsa.tf), which reuses the broad ECS-parity
# policy. This role is the FAIL-CLOSED guarantee for #619: a preview sandbox
# physically CANNOT
#   - read dev's DB credentials (SSM is scoped to /idseq-sandbox-pr-*-web/*, never
#     /idseq-dev-web/*), nor
#   - write dev's data buckets (S3 write is scoped to seqtoid-sandbox/*, never the
#     dev samples buckets).
# Reference/taxon data is shared READ-ONLY; the shared dev SFN/Batch backend is
# reachable so a sandbox can actually run pipelines.
#
# TRUST: StringLike on the namespace segment (seqtoid-pr-*) so every per-PR namespace's
# seqtoid-web SA can assume it, via the same czid-dev-eks-v2 OIDC provider the dev role
# uses (data.aws_eks_cluster.dev_eks_v2 is declared in eks-irsa.tf, same stack).
#
# ADDITIVE -- a new role + 3 inline policies. Apply with `-target` (dev/web carries
# unrelated drift). NOT wired to any live sandbox until the #619 isolation gate passes.
# =============================================================================

locals {
  # The chamber SecureString KMS key for SSM params (same key the dev params policy uses).
  seqtoid_preview_chamber_kms_key = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/d60c5ad2-9fc6-4306-87cd-b0d797804f1c"
}

# IRSA trust: the seqtoid-web SA in ANY seqtoid-pr-* namespace on czid-dev-eks-v2.
data "aws_iam_policy_document" "seqtoid_web_preview_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].provider_arn]
    }
    # StringLike so pr-1, pr-2, ... all match; the SA name is pinned to seqtoid-web.
    condition {
      test     = "StringLike"
      variable = "${local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].issuer_host}:sub"
      values   = ["system:serviceaccount:seqtoid-pr-*:seqtoid-web"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seqtoid_web_preview" {
  name               = "seqtoid-web-preview"
  description        = "IRSA role for per-PR preview sandboxes (seqtoid-pr-*); scoped fail-closed vs the dev role (#618/#619)"
  assume_role_policy = data.aws_iam_policy_document.seqtoid_web_preview_trust.json
}

# 1) SSM read -- SANDBOX PATH ONLY. This is the core DB-credential isolation: the role
#    cannot read /idseq-dev-web/* (dev's DB creds), only the per-PR sandbox path.
data "aws_iam_policy_document" "seqtoid_web_preview_params" {
  statement {
    sid = "SandboxSsmReadOnly"
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-sandbox-pr-*-web/*"]
  }
  statement {
    sid       = "ChamberKmsDecrypt"
    actions   = ["kms:Decrypt"]
    resources = [local.seqtoid_preview_chamber_kms_key]
  }
  statement {
    sid       = "ChamberDescribeParameters"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
  # chamber reads its OWN store-config parameter before it will read ANY path. It lives at
  # /_chamber/store-config, outside the idseq-sandbox-* path granted above, so `chamber exec` -- which
  # is how every sandbox pod starts -- died with AccessDenied BEFORE Rails booted. The pod exited 1
  # with zero log lines, which makes this look like a crash rather than a permissions problem.
  #
  # The provisioner role hit exactly the same gap (see eks-irsa-preview-provisioner.tf). Read-only, a
  # single fixed key, and it is chamber's bookkeeping -- not application config.
  statement {
    sid = "ChamberStoreConfig"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/_chamber/store-config"]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_preview_params" {
  name   = "seqtoid-web-preview-parameter-policy"
  role   = aws_iam_role.seqtoid_web_preview.id
  policy = data.aws_iam_policy_document.seqtoid_web_preview_params.json
}

# 2) S3 -- read reference/taxon data (shared, read-only) + read/write ONLY the sandbox
#    bucket. NO write to dev's samples buckets (the S3 isolation guarantee).
data "aws_iam_policy_document" "seqtoid_web_preview_s3" {
  statement {
    sid     = "SandboxAndReferenceList"
    actions = ["s3:ListBucket", "s3:ListBucketMultipartUploads", "s3:GetBucketLocation"]
    resources = [
      aws_s3_bucket.preview_samples.arn,
      "arn:aws:s3:::seqtoid-sandbox",
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}",
    ]
  }
  statement {
    sid     = "SandboxAndReferenceRead"
    actions = ["s3:GetObject", "s3:GetObjectTagging"]
    resources = [
      "${aws_s3_bucket.preview_samples.arn}/*",
      "arn:aws:s3:::seqtoid-sandbox/*",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
    ]
  }
  statement {
    # WRITE is fail-closed to the dedicated preview bucket ONLY.
    #
    # This used to target `arn:aws:s3:::seqtoid-sandbox/*`, on the reasoning that "the role bounds
    # the blast radius to the sandbox bucket regardless" while per-PR prefix isolation was
    # "enforced by the pod's SAMPLES_BUCKET_NAME". That reasoning assumed seqtoid-sandbox was a
    # throwaway. It is not: it is a hand-created, un-terraformed bucket holding ~4.8 TB / 55k
    # objects of the team's research data (validation-*, time-trials-*, taxid_indexes/, jsims/
    # ...), backup status unknown. So the blast radius was that data, and the only thing keeping a
    # sandbox out of it was a config STRING -- any bug in a sandbox could delete research results.
    #
    # Isolation is now enforced by IAM against a dedicated bucket, which is what "isolated" was
    # always supposed to mean. READ on seqtoid-sandbox is retained above (sandboxes may pull
    # test-files/ etc.); WRITE and DELETE on it are withdrawn deliberately. Do not add them back.
    sid       = "PreviewSamplesWriteOnly"
    actions   = ["s3:PutObject", "s3:PutObjectTagging", "s3:DeleteObject", "s3:AbortMultipartUpload"]
    resources = ["${aws_s3_bucket.preview_samples.arn}/*"]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_preview_s3" {
  name   = "seqtoid-web-preview-s3-policy"
  role   = aws_iam_role.seqtoid_web_preview.id
  policy = data.aws_iam_policy_document.seqtoid_web_preview_s3.json
}

# 3) Pipeline backend -- dispatch to the SHARED dev Step Functions + submit to Batch, and
#    read the token-signing secret. SQS is scoped to sandbox queues only so a sandbox can
#    never inject work into dev's worker queues (idseq-<env>-*). No lambda:InvokeFunction
#    (the MySQL->ES indexing Lambda is intentionally NOT targeted per-sandbox; ES indexing
#    is disabled in preview, see the #619 gate).
data "aws_iam_policy_document" "seqtoid_web_preview_backend" {
  # The only "*" resources below are read-only status actions (states List*, batch
  # Describe*/List*) that do NOT support resource-level IAM permissions; every WRITE
  # action (StartExecution, SubmitJob, ...) is scoped to the dev pipeline ARNs.
  #checkov:skip=CKV_AWS_356:read-only states List*/batch Describe*+List* do not support resource-level scoping; all writes are ARN-scoped
  # SFN: dispatch to + monitor the SHARED dev state machines. Writes scoped to the dev
  # state-machine ARNs (idseq-swipe-<env>-*).
  statement {
    sid = "SfnDispatchDev"
    actions = [
      "states:StartExecution",
      "states:StopExecution",
      "states:DescribeStateMachine",
    ]
    resources = ["arn:aws:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:idseq-swipe-${var.env}-*"]
  }
  statement {
    sid = "SfnMonitorDev"
    actions = [
      "states:DescribeExecution",
      "states:GetExecutionHistory",
    ]
    resources = ["arn:aws:states:${var.region}:${data.aws_caller_identity.current.account_id}:execution:idseq-swipe-${var.env}-*:*"]
  }
  # Batch: submit/terminate scoped to the dev job queues + definitions.
  statement {
    sid = "BatchSubmitDev"
    actions = [
      "batch:SubmitJob",
      "batch:TerminateJob",
    ]
    resources = [
      "arn:aws:batch:${var.region}:${data.aws_caller_identity.current.account_id}:job-queue/*",
      "arn:aws:batch:${var.region}:${data.aws_caller_identity.current.account_id}:job-definition/*",
      "arn:aws:batch:${var.region}:${data.aws_caller_identity.current.account_id}:job/*",
    ]
  }
  # Read-only pipeline status. These states/batch List*+Describe* actions do not support
  # resource-level permissions, so they require "*" (read-only; no data/isolation impact).
  statement {
    sid = "PipelineReadOnlyStatus"
    actions = [
      "states:ListExecutions",
      "states:ListStateMachines",
      "batch:DescribeJobs",
      "batch:ListJobs",
      "batch:DescribeJobQueues",
      "batch:DescribeJobDefinitions",
      "batch:DescribeComputeEnvironments",
    ]
    resources = ["*"]
  }
  statement {
    # Sandbox-only SQS: cannot touch dev's idseq-<env>-* / idseq-swipe-<env>-* queues.
    sid = "SandboxSqsOnly"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
      "sqs:ListQueues",
    ]
    resources = ["arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:idseq-sandbox-*"]
  }
  statement {
    # The token-auth signing key (scripts/token_auth.py). Read-only, shared dev secret.
    sid       = "TokenSigningSecretRead"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}/czid-services-private-key*"]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_preview_backend" {
  name   = "seqtoid-web-preview-backend-policy"
  role   = aws_iam_role.seqtoid_web_preview.id
  policy = data.aws_iam_policy_document.seqtoid_web_preview_backend.json
}

output "seqtoid_web_preview_role_arn" {
  description = "ARN of the per-PR preview IRSA role -- set as serviceAccount.roleArn in the preview ApplicationSet (#617)."
  value       = aws_iam_role.seqtoid_web_preview.arn
}
