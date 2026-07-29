# =============================================================================
# Per-PR sandbox PROVISIONER IRSA role -- seqtoid-web-preview-provisioner (#616).
#
# Provisioning a sandbox needs ELEVATED, short-lived access the running app must NOT
# have: read dev's secret set (to copy the shared config), WRITE the per-PR SSM path,
# and (via the copied master DB creds) create the per-PR schema + scoped DB user. This
# role is assumed ONLY by the ephemeral provision/teardown Jobs (ServiceAccount
# seqtoid-web-provisioner), NEVER by the app pods -- those use the tightly-scoped
# seqtoid-web-preview role (eks-irsa-preview.tf). Keeping the elevated identity on a
# separate, hook-only SA is what preserves the sandbox's fail-closed posture.
#
# What it can do:
#   - READ dev's SSM (/idseq-dev-web/*) -- to copy the shared, non-DB config into the
#     per-PR path. (This is the one identity allowed to; the app role cannot.)
#   - WRITE + DELETE the per-PR SSM path (/idseq-sandbox-pr-*-web/*).
#   - KMS encrypt/decrypt with the chamber SecureString key (read dev params, write
#     sandbox params as SecureString).
# It does NOT get S3/SFN/Batch/samples -- provisioning is secrets + DB schema only. The
# DB schema + scoped user are created in-cluster by the Job using the master creds it
# reads here (the app image can reach the dev Aurora; a GitHub runner cannot).
#
# TRUST: StringLike system:serviceaccount:seqtoid-pr-*:seqtoid-web-provisioner on the
# czid-dev-eks-v2 OIDC provider. Additive; apply with -target. Not wired until the
# provision Job (SW chart) + #619 gate land.
# =============================================================================

data "aws_iam_policy_document" "seqtoid_web_provisioner_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].provider_arn]
    }
    condition {
      test     = "StringLike"
      variable = "${local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].issuer_host}:sub"
      values   = ["system:serviceaccount:seqtoid-pr-*:seqtoid-web-provisioner"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seqtoid_web_provisioner" {
  name               = "seqtoid-web-preview-provisioner"
  description        = "Elevated, hook-only role for per-PR sandbox provision/teardown Jobs (#616); NOT for app pods"
  assume_role_policy = data.aws_iam_policy_document.seqtoid_web_provisioner_trust.json
}

data "aws_iam_policy_document" "seqtoid_web_provisioner" {
  # Read dev's secret set to copy the shared (non-DB) config into the per-PR path, plus
  # the master DB creds the Job uses (in-cluster) to create the schema + scoped user.
  statement {
    sid = "ReadDevSsmToCopy"
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-${var.env}-web/*"]
  }
  # Own the per-PR SSM path: write the sandbox's scoped config, and delete it on teardown.
  statement {
    sid = "WriteSandboxSsm"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:AddTagsToResource",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-sandbox-pr-*-web/*"]
  }
  statement {
    sid       = "ChamberKms"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/d60c5ad2-9fc6-4306-87cd-b0d797804f1c"]
  }
  statement {
    sid       = "ChamberDescribeParameters"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
  # chamber reads its OWN store-config parameter before it will write to any path. It lives at
  # /_chamber/store-config, outside every idseq-* path granted above, so `chamber import` failed
  # AccessDenied on the sandbox provision Job even though the sandbox path itself was writable.
  # Read-only, and a single fixed key -- chamber's bookkeeping, not application config.
  statement {
    sid = "ChamberStoreConfig"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/_chamber/store-config"]
  }
  # The provision COPIES the SHARED sandbox config -- the isolated OpenSearch endpoints
  # (ES_ADDRESS / HEATMAP_ES_ADDRESS at /idseq-sandbox-web/*, written by the heatmap-sandbox
  # component, web-infra #41) -- into each per-PR path. Reading that shared path was never
  # granted: the reads above cover only dev (/idseq-${var.env}-web/*) and the per-PR path
  # (/idseq-sandbox-pr-*-web/*). So sandbox.rake's fail-closed sandbox_shared_es_address helper
  # hit AccessDenied on /idseq-sandbox-web/HEATMAP_ES_ADDRESS and EVERY new sandbox provision
  # aborted before deploying the app (platform-overhaul #732; observed on seqtoid-pr-70). The
  # schema/user/grants are created first, so this only breaks the app bring-up. Read-only, and
  # the shared path holds only the sandbox ES endpoints -- never DB creds.
  statement {
    sid = "ReadSharedSandboxConfig"
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-sandbox-web/*"]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_provisioner" {
  name   = "seqtoid-web-preview-provisioner-policy"
  role   = aws_iam_role.seqtoid_web_provisioner.id
  policy = data.aws_iam_policy_document.seqtoid_web_provisioner.json
}

output "seqtoid_web_provisioner_role_arn" {
  description = "ARN of the sandbox provisioner role -- set as the provisioner ServiceAccount's roleArn in the preview ApplicationSet (#617)."
  value       = aws_iam_role.seqtoid_web_provisioner.arn
}
