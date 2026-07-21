# =============================================================================
# Sandbox ORPHAN REAPER IRSA role -- seqtoid-sandbox-reaper (#697).
#
# WHY THIS EXISTS: per-PR sandbox teardown is BEST-EFFORT. Its PostDelete hook has three
# known ways to never run, each stranding a schema that now contains COPIED USER PII
# (sandbox:seed_users):
#   (a) the teardown Job renders from the PR head SHA, but the gitops flow closes PRs with
#       --delete-branch -- once that commit is unreachable the hook cannot render;
#   (b) it pulls seqtoid-web-preview:sha-<head8>, and that repo expires all but the 30 most
#       recent tags, so a long-lived PR cannot pull its own teardown image;
#   (c) any failed teardown Job wedges deletion behind the Argo finalizer forever.
# In every case the only signal is an Application stuck Terminating. This system has already
# lost cleanup twice (leaked ~40 SSM params, #288; orphaned namespaces, #257). A hook that
# usually runs is not a retention guarantee -- which is the bar once the data is PII.
#
# The reaper (a CronJob in `argocd`, deploy/argocd/_deliberate/sandbox-orphan-reaper.yaml)
# depends on none of that machinery: it lists the schemas + SSM paths that physically exist,
# asks GitHub which PRs are open, and tears down the difference via `rake sandbox:reap_orphans`.
#
# It runs from a STABLE image (seqtoid-web:latest, which the ECR lifecycle explicitly never
# expires) -- never a per-PR tag, which would be failure mode (b) all over again.
#
# WHY A SEPARATE ROLE from seqtoid-web-preview-provisioner: that role's trust is
# StringLike system:serviceaccount:seqtoid-pr-*:seqtoid-web-provisioner -- scoped to a
# sandbox's OWN namespace, which by definition no longer exists once a sandbox is orphaned.
# The reaper lives in `argocd` and needs its own trust. It is deliberately NOT granted
# ssm:PutParameter: the reaper only ever DESTROYS, so it cannot seed or mutate a sandbox.
#
# TRUST: StringEquals system:serviceaccount:argocd:seqtoid-sandbox-reaper (exact, not a
# wildcard -- there is exactly one reaper).
# =============================================================================

data "aws_iam_policy_document" "seqtoid_sandbox_reaper_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].issuer_host}:sub"
      values   = ["system:serviceaccount:argocd:seqtoid-sandbox-reaper"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.seqtoid_web_eks_oidc["czid-dev-eks-v2"].issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seqtoid_sandbox_reaper" {
  name               = "seqtoid-sandbox-reaper"
  description        = "Scheduled backstop that reaps orphaned per-PR sandbox schemas/users/SSM paths (#697); destroy-only"
  assume_role_policy = data.aws_iam_policy_document.seqtoid_sandbox_reaper_trust.json
}

data "aws_iam_policy_document" "seqtoid_sandbox_reaper" {
  # Read dev's config for the MASTER DB creds -- the reaper must connect as master to DROP an
  # orphaned schema + its scoped user. Read-only; it never writes this path.
  statement {
    sid = "ReadDevSsmForMasterCreds"
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-${var.env}-web/*"]
  }

  # Destroy an orphaned sandbox's SSM path. NOTE both ARNs: GetParametersByPath authorises
  # against the PATH itself (parameter/idseq-sandbox-pr-N-web), not its children, so the
  # bare-path ARN is required for enumeration while /* covers the individual params. The
  # provisioner role omits the bare path, which is why enumeration there only works with a
  # trailing slash on --path (see the note in lib/tasks/sandbox.rake). Granting both here
  # makes the reaper independent of that subtlety.
  # NO ssm:PutParameter -- the reaper is destroy-only by design.
  statement {
    sid = "DestroyOrphanedSandboxSsm"
    actions = [
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-sandbox-pr-*-web",
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-sandbox-pr-*-web/*",
    ]
  }

  # Enumerate which sandbox paths exist at all. DescribeParameters does not accept a resource
  # scope in IAM (it is a list-style API), so "*" is required; it returns NAMES only, never
  # values, and reading any value still requires the scoped statements above.
  # checkov:skip=CKV_AWS_356:ssm:DescribeParameters cannot be resource-scoped; it exposes names only
  statement {
    sid       = "EnumerateParameterNames"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }

  # chamber reads its own /_chamber/store-config key before touching any path (see #286/#296 --
  # this exact grant being missing is what made `chamber exec` die with zero log lines).
  statement {
    sid = "ChamberStoreConfig"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/_chamber/store-config"]
  }

  # SecureString decryption for the two paths above.
  statement {
    sid       = "ChamberKmsDecrypt"
    actions   = ["kms:Decrypt"]
    resources = [local.seqtoid_preview_chamber_kms_key]
  }
}

resource "aws_iam_role_policy" "seqtoid_sandbox_reaper" {
  name   = "seqtoid-sandbox-reaper"
  role   = aws_iam_role.seqtoid_sandbox_reaper.id
  policy = data.aws_iam_policy_document.seqtoid_sandbox_reaper.json
}

output "seqtoid_sandbox_reaper_role_arn" {
  description = "IRSA role ARN for the sandbox orphan reaper CronJob (annotate SA argocd/seqtoid-sandbox-reaper)"
  value       = aws_iam_role.seqtoid_sandbox_reaper.arn
}
