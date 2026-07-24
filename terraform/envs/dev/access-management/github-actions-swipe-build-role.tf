# =============================================================================
# GitHub Actions BUILD role for swipe -- czid-dev-gh-actions-swipe-build
# (dev account, 491013321714).
#
# swipe's publish-image.yml assumes this role to log in to ECR and push the swipe
# pipeline-orchestrator image it builds from source. It reuses the dev OIDC provider
# already created in this stack (github-actions-runner-permissions.tf) -- no new
# provider.
#
# WHY A SEPARATE ROLE rather than widening czid-dev-gh-actions-workflows-build:
# that role is deliberately scoped to seqtoid-workflows in BOTH its OIDC trust and
# its ECR resource list (the 11 WDL workflow repos; `swipe` is not among them). It
# is the same least-privilege shape as czid-dev-gh-actions-build, which is scoped to
# seqtoid-web. Widening the workflows role would mean the swipe repo could push
# short-read-mngs / index-generation images and the workflows repo could overwrite
# the orchestrator image -- a lateral blast radius across three unrelated repos for
# no benefit. One role per publishing repo, scoped to that repo's own ECR
# repository, keeps "compromise of repo X can only republish X's image" true.
#
# WHY IT IS NEEDED: swipe could not push at all. No dev role trusts
# repo:*/swipe:*, so the OIDC AssumeRole would fail with "Not authorized to perform
# sts:AssumeRoleWithWebIdentity". swipe's only image-publish workflow
# (.github/workflows/push-docker-images.yml) was ALSO entirely commented out and
# targeted ghcr.io rather than this account's ECR, so it had never run. The net
# effect: the only swipe image in dev ECR was hand-built and hand-pushed, and was
# arm64-only while the user-facing Batch compute environments are x86_64 -- an
# arch/tag mismatch that took every user workflow down with
# CannotPullImageManifestError. This role is the durable fix's first half; the
# second half is the CI workflow in the swipe repo.
#
# APPLY NOTE -- THIS CANNOT BE APPLIED BY CI. czid-dev-gh-actions-apply carries
# czid-dev-gh-actions-apply-iam-provisioning, whose DenyCIIdentitySelfModification
# statement explicitly DENIES iam:CreateRole / iam:CreatePolicy / iam:AttachRolePolicy
# (and friends) on arn:aws:iam::<acct>:role/czid-dev-gh-actions-* and
# .../policy/czid-dev-gh-actions-*. That deny is an anti-privilege-escalation guard:
# CI must never be able to mint or widen its own identity. This role is deliberately
# named inside that namespace and is therefore deliberately un-appliable by CI. It
# must be applied out-of-band with admin credentials, exactly as
# czid-dev-gh-actions-workflows-build and the CZID-81 bootstrap were. Do not rename
# it to escape the deny; the deny is doing its job.
# =============================================================================

module "czid_gh_actions_swipe_build" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-swipe-build"
  }
  # Scope the trust to the swipe repo only. subject_ref_pattern="*" supports both the
  # push/tag-triggered publish and the on-demand workflow_dispatch image cut; the
  # module's C1 guard still DENIES :pull_request subjects (a fork PR can never assume
  # it), which is what keeps a drive-by PR from publishing the orchestrator image.
  authorized_github_repos = {
    for org in local.gh_orgs : org => ["swipe"]
  }
  subject_ref_pattern = "*"
}

# Least-privilege ECR push: account-wide auth token (required for `docker login`, cannot
# be resource-scoped) + image push/pull scoped to the `swipe` repository only.
#
# DescribeImages / BatchGetImage / GetDownloadUrlForLayer are read verbs the publish
# workflow's multi-arch verification step needs: it walks the published manifest index,
# fetches each child manifest, and then downloads that child's CONFIG BLOB to read the
# architecture the image actually declares. A manifest list's platform fields are
# author-supplied metadata and can disagree with the image; the config blob cannot.
data "aws_iam_policy_document" "swipe_build_ecr_push" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushToSwipeRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${local.account_id}:repository/swipe",
    ]
  }
}

resource "aws_iam_policy" "swipe_build_ecr_push" {
  name   = "czid-${var.env}-gh-actions-swipe-build-ecr-push"
  policy = data.aws_iam_policy_document.swipe_build_ecr_push.json
}

resource "aws_iam_role_policy_attachment" "swipe_build_ecr_push" {
  role       = module.czid_gh_actions_swipe_build.role.name
  policy_arn = aws_iam_policy.swipe_build_ecr_push.arn
}

output "swipe_build_role_arn" {
  description = "ARN of czid-dev-gh-actions-swipe-build (the swipe repo's publish-image workflow assumes this to push the orchestrator image to dev ECR)."
  value       = module.czid_gh_actions_swipe_build.role.arn
}
