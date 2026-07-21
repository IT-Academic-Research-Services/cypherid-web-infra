# Shared SSOT module: the Argo Rollouts controller IRSA role (platform-overhaul 782).
#
# One definition; every EKS env instantiates it with its own cluster name + OIDC
# provider ARN. The Argo Rollouts controller -- installed cluster-wide via the Argo CD
# Application in deploy/argocd/_terraform-owned/argo-rollouts.yaml -- runs under the
# argo-rollouts:argo-rollouts service account and assumes this role (IRSA) so its
# --aws-verify-target-group check can call the read-only elbv2 Describe* APIs. That
# check confirms the new color's ALB target group is healthy before the old color is
# scaled down, which is what makes ping-pong (canary + weighted target groups) cutovers
# zero-downtime. Without these permissions the verification fails (no AWS creds).
#
# Read-only by design: the controller only DESCRIBES target groups/health here. All
# mutating ALB/target-group actions stay with the AWS Load Balancer Controller (its own
# IRSA role, terraform/modules/lb-controller-irsa). The permission set is vendored
# in-tree as iam-policy.json (no registry module, no network at init, one source of
# truth), matching the lb-controller-irsa vendoring convention.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Scope the trust to exactly the Argo Rollouts controller's service account.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

locals {
  oidc_provider_url = replace(var.oidc_issuer_url, "https://", "")
}

resource "aws_iam_role" "this" {
  name                 = "${var.cluster_name}-argo-rollouts"
  description          = "IRSA role for the Argo Rollouts controller on ${var.cluster_name} (--aws-verify-target-group; platform-overhaul 782)"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-argo-rollouts"
  description = "Read-only elbv2 Describe* for Argo Rollouts --aws-verify-target-group on ${var.cluster_name} (platform-overhaul 782)"
  policy      = file("${path.module}/iam-policy.json")
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
