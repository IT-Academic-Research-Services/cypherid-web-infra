# =============================================================================
# IRSA role for the seqtoid-web pod on the prod-preview EKS cluster (prod account 283694049553).
# Mirrors envs/sandbox/web/eks-irsa.tf. Role name seqtoid-web-<env> = seqtoid-web-prod-preview, the
# roleArn referenced by deploy/argocd/values/seqtoid-web/prod-preview.yaml.
#
# TRUST: the prod-preview EKS cluster's OIDC provider (foundation names it <name_prefix>-<env> =
# seqtoid-prod-preview), scoped to the seqtoid-web ServiceAccount in namespace seqtoid-prod-preview.
#
# ORDERING: data.aws_eks_cluster reads the LIVE cluster's OIDC issuer, so the prod-preview foundation
# (which creates seqtoid-prod-preview + its IAM OIDC provider) must be applied BEFORE this stack.
#
# APP POLICY -- DIFFERENT FROM SANDBOX: sandbox reused its env's existing
# data.aws_iam_policy_document.idseq-web (a fogg-generated ECS-task doc). prod-preview is GREENFIELD
# (no legacy env dir, no such doc), so the app S3/SQS/etc. policy must be authored as part of the
# env's data-layer buildout -- it references the env's own bucket/queue names, which do not exist yet.
# Below: the role + trust + the parameter policy are COMPLETE and functional; the app policy is a
# marked TODO. The role is assumable and can read its chamber params, but grants no app perms until
# the app policy is attached. (Longer term, eks-irsa.tf is a copy-per-env anti-pattern -> extract a
# shared module; noted, out of scope for this draft.)
# =============================================================================

data "aws_eks_cluster" "prod_preview" {
  name = "${var.name_prefix}-${var.env}" # seqtoid-prod-preview
}

locals {
  seqtoid_web_eks_namespace = "seqtoid-${var.env}" # seqtoid-prod-preview
  seqtoid_web_eks_sa        = "seqtoid-web"

  pp_oidc_issuer      = data.aws_eks_cluster.prod_preview.identity[0].oidc[0].issuer
  pp_oidc_issuer_host = replace(local.pp_oidc_issuer, "https://", "")
  pp_oidc_provider_arn = format(
    "arn:aws:iam::%s:oidc-provider/%s",
    data.aws_caller_identity.current.account_id,
    local.pp_oidc_issuer_host,
  )
}

data "aws_iam_policy_document" "seqtoid_web_eks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.pp_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.pp_oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${local.seqtoid_web_eks_namespace}:${local.seqtoid_web_eks_sa}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.pp_oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "seqtoid_web_eks" {
  name               = "seqtoid-web-${var.env}"
  description        = "IRSA role for the seqtoid-web pod on ${var.name_prefix}-${var.env} (locked-down pre-prod)"
  assume_role_policy = data.aws_iam_policy_document.seqtoid_web_eks_trust.json
}

# Chamber/SSM parameter read (COMPLETE). Params under /idseq-<env>-web/* + DescribeParameters + the
# optional chamber SecureString KMS key (parameterised; empty = AWS-managed SSM key).
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

# TODO(app policy): author the app S3/SQS/Lambda/Secrets/Batch policy for prod-preview and attach it
# as aws_iam_role_policy.seqtoid_web_eks_app -> data.aws_iam_policy_document.<app>. Port the SHAPE from
# envs/dev/web (data.aws_iam_policy_document.idseq-web), pointed at prod-preview's OWN bucket/queue
# names (isolated, synthetic data). Deliberately omitted here so this draft asserts no app permissions
# against the prod account before the data layer + its names are defined.

output "seqtoid_web_eks_role_arn" {
  description = "ARN of the seqtoid-web IRSA role -- set as serviceAccount.roleArn in values/seqtoid-web/prod-preview.yaml."
  value       = aws_iam_role.seqtoid_web_eks.arn
}
