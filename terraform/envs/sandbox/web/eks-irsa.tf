# =============================================================================
# IRSA role for the seqtoid-web pod on the sandbox EKS cluster.
# Mirrors envs/dev/web/eks-irsa.tf, reduced to the single sandbox cluster.
#
# NAMING: `seqtoid-web-<env>` (new scheme) -> seqtoid-web-sandbox. This is the roleArn the
# chart values reference (deploy/argocd/values/seqtoid-web/sandbox.yaml).
#
# TRUST: the sandbox EKS cluster's OIDC provider, scoped to the seqtoid-web ServiceAccount in
# the seqtoid-<env> namespace. The foundation names the cluster ${name_prefix}-${environment}
# = seqtoid-sandbox (name_prefix "seqtoid" for the fresh build).
#
# ORDERING: data.aws_eks_cluster reads the LIVE cluster's OIDC issuer, so the sandbox foundation
# (which creates seqtoid-sandbox + its IAM OIDC provider) must be applied BEFORE this stack. On a
# fresh reconstitute that is the provision stage; this web stack applies after.
#
# PERMISSIONS (ported from envs/dev/web/eks-irsa.tf):
#   * App policy REUSES this env's existing ECS-task policy document
#     (data.aws_iam_policy_document.idseq-web in main.tf) -- it is already
#     var.s3_bucket_*-parameterised, so the pod gets the SAME S3/SQS/etc. perms as the legacy
#     idseq-web role for THIS account. Exact parity, exactly as dev does it.
#   * Parameter policy is ported inline, with the chamber SecureString KMS key parameterised
#     (var.chamber_kms_key_arn) -- dev hardcodes its own account's key, which does not exist here.
#     SSM path is env-parameterised (/idseq-<env>-web/* -> /idseq-sandbox-web/*).
#
# Reuses the env's existing `data "aws_caller_identity" "current"` (declared in main.tf).
# =============================================================================

data "aws_eks_cluster" "sandbox" {
  name = "${var.name_prefix}-${var.env}" # seqtoid-sandbox; set var.name_prefix if this env lacks it
}

locals {
  seqtoid_web_eks_namespace = "seqtoid-${var.env}" # seqtoid-sandbox
  seqtoid_web_eks_sa        = "seqtoid-web"

  sandbox_oidc_issuer      = data.aws_eks_cluster.sandbox.identity[0].oidc[0].issuer
  sandbox_oidc_issuer_host = replace(local.sandbox_oidc_issuer, "https://", "")
  sandbox_oidc_provider_arn = format(
    "arn:aws:iam::%s:oidc-provider/%s",
    data.aws_caller_identity.current.account_id,
    local.sandbox_oidc_issuer_host,
  )
}

# Only the seqtoid-web ServiceAccount in the seqtoid-sandbox namespace may assume this role.
data "aws_iam_policy_document" "seqtoid_web_eks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.sandbox_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.sandbox_oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${local.seqtoid_web_eks_namespace}:${local.seqtoid_web_eks_sa}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.sandbox_oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seqtoid_web_eks" {
  name               = "seqtoid-web-${var.env}"
  description        = "IRSA role for the seqtoid-web pod on ${var.name_prefix}-${var.env} (sandbox rehearsal env)"
  assume_role_policy = data.aws_iam_policy_document.seqtoid_web_eks_trust.json
}

# 1) App permissions -- REUSE this env's ECS-task policy document for exact parity (S3, SQS, Lambda,
#    Secrets Manager, CloudWatch, Batch, ...). It is already parameterised by this env's
#    var.s3_bucket_* etc., so it grants the sandbox-scoped resources, not dev's.
resource "aws_iam_role_policy" "seqtoid_web_eks_app" {
  name   = "seqtoid-web-${var.env}-app"
  role   = aws_iam_role.seqtoid_web_eks.id
  policy = data.aws_iam_policy_document.idseq-web.json
}

# 2) Chamber/SSM parameter read -- mirrors the live idseq-<env>-web-parameter-policy: params under
#    /idseq-<env>-web/* + the SecureString KMS key + the account-wide DescribeParameters chamber needs.
data "aws_iam_policy_document" "seqtoid_web_eks_params" {
  statement {
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameterHistory",
      "ssm:GetParameter",
    ]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/idseq-${var.env}-web/*"]
  }

  # kms:Decrypt on the sandbox chamber SecureString key. Dev hardcodes its own account's key; here it
  # is a variable because the key is account-specific. Omitted entirely when unset (params encrypted
  # with the AWS-managed SSM key need no explicit grant) -- fill var.chamber_kms_key_arn if sandbox
  # uses a customer-managed CMK for /idseq-sandbox-web/* SecureStrings.
  dynamic "statement" {
    for_each = var.chamber_kms_key_arn == "" ? [] : [var.chamber_kms_key_arn]
    content {
      actions   = ["kms:Decrypt"]
      resources = [statement.value]
    }
  }

  statement {
    sid       = "ChamberSSMReadRequirement"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "seqtoid_web_eks_params" {
  name   = "seqtoid-web-${var.env}-parameter-policy"
  role   = aws_iam_role.seqtoid_web_eks.id
  policy = data.aws_iam_policy_document.seqtoid_web_eks_params.json
}

# The sandbox chamber SecureString KMS key ARN for /idseq-sandbox-web/* params. Empty by default:
# with no customer CMK the pod reads params via the AWS-managed SSM key and needs no kms:Decrypt
# grant. Set this to the real key ARN if sandbox chamber params are encrypted with a customer CMK.
variable "chamber_kms_key_arn" {
  description = "KMS key ARN for the sandbox chamber SecureString params (empty = AWS-managed SSM key, no explicit grant)."
  type        = string
  default     = ""
}

output "seqtoid_web_eks_role_arn" {
  description = "ARN of the seqtoid-web IRSA role -- set as serviceAccount.roleArn in deploy/argocd/values/seqtoid-web/sandbox.yaml."
  value       = aws_iam_role.seqtoid_web_eks.arn
}

# var.name_prefix: the foundation's resource-name prefix (cluster = <name_prefix>-<env>). Declared
# here (not in the env yet) so the cluster lookup is explicit and overridable. Remove if the env
# adds it centrally.
variable "name_prefix" {
  description = "Foundation resource-name prefix; the sandbox EKS cluster is <name_prefix>-<env>."
  type        = string
  default     = "seqtoid"
}
