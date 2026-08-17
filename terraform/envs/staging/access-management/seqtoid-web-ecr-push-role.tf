# =============================================================================
# SMP-1775: cross-account ECR-push role for image promotion.
#
# seqtoid-web's `.github/workflows/promote-to-env.yml` (PR adding a pre-advance
# `skopeo copy --all`) assumes a DESTINATION env-account role via GitHub OIDC and
# pushes the promoted image digest into THIS account's `seqtoid-web` ECR repo so
# Argo can pull it (fixes ImagePullBackOff). The workflow builds the ARN as
# `arn:aws:iam::${vars.ENV_ACCOUNT_ID}:role/${vars.ENV_ECR_WRITE_ROLE}`, so the
# GitHub Environment `staging` must set:
#   ENV_ACCOUNT_ID     = 030998640247
#   ENV_ECR_WRITE_ROLE = czid-staging-gh-actions-ecr-push   (role NAME, not ARN)
#
# The role trusts the EXISTING GitHub OIDC provider for this account
# (aws_iam_openid_connect_provider.github, declared in
# github-actions-runner-permissions.tf) -- the reusable module federates through
# it via caller-identity, so NO second provider is created. The trust is scoped
# tightly: only the promote job's OIDC subject
# `repo:IT-Academic-Research-Services/seqtoid-web:environment:staging` may assume
# it (the advance job runs under `environment: staging`, so the git ref is not in
# the sub -- the environment subject is what GitHub issues). thorvath-slower is
# deliberately EXCLUDED: it is the frozen origin (zombie fork crons must never be
# able to push into the staging registry). aud is pinned to sts.amazonaws.com and
# the module's C1 `:pull_request` deny still applies.
#
# Least-privilege: the attached policy allows ONLY an ECR push to the staging
# `seqtoid-web` repository (plus the un-scopeable GetAuthorizationToken). It
# cannot pull, delete, or touch any other repo, and it cannot mutate any AWS
# resource beyond that push.
#
# APPLY IS OPERATOR/ADMIN, NOT THE CI tf-apply CHANNEL. The apply role's
# DenyCIIdentitySelfModification statement denies iam:CreateRole /
# CreatePolicy / AttachRolePolicy on `czid-staging-gh-actions-*` and
# `czid-staging-*` policy names, so a CI apply of this component fails closed.
# This must be applied out-of-band with admin credentials (as the CZID-81
# bootstrap was). HELD pending operator apply.
# =============================================================================

module "czid_gh_actions_ecr_push" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-ecr-push"
  }

  # Scope the trust to the canonical repo ONLY (itars is the canonical origin;
  # thorvath-slower is intentionally omitted -- see header).
  authorized_github_repos = {
    "IT-Academic-Research-Services" = ["seqtoid-web"]
  }

  # The promote `advance` job runs under `environment: staging`, so GitHub issues
  # the OIDC token with sub `repo:<org>/<repo>:environment:staging` (the git ref is
  # NOT in the sub once an environment is attached). Match that exact subject --
  # the tightest existing pattern, identical in shape to the apply role's
  # `environment:${var.env}`.
  subject_ref_pattern = "environment:${var.env}"
}

# --- Least-privilege ECR push to the staging seqtoid-web repo ONLY ------------
# skopeo copy --all needs to check/upload layers and put the (multi-arch) manifest.
# GetAuthorizationToken cannot be resource-scoped (must be "*"); every mutating
# action is scoped to the single `seqtoid-web` repository ARN. No pull, no delete,
# no other repo. Region is wildcarded to mirror the sibling apply_ecr policy; the
# repo only exists in us-west-2, so this is not a real widening.
resource "aws_iam_policy" "ecr_push" {
  name   = "czid-${var.env}-gh-actions-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken cannot be resource-scoped
  }
  statement {
    sid = "EcrPushSeqtoidWeb"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      "arn:aws:ecr:*:${local.account_id}:repository/seqtoid-web",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = module.czid_gh_actions_ecr_push.role.name
  policy_arn = aws_iam_policy.ecr_push.arn
}
