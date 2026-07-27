# =============================================================================
# GitHub Actions BUILD role for seqtoid-workflows -- czid-dev-gh-actions-workflows-build
# (dev account, 491013321714).
#
# seqtoid-workflows' wdl-ci.yml assumes this role to log in to ECR and push the WDL
# workflow images it builds from source (index-generation, short-read-mngs, ...). It
# reuses the dev OIDC provider already created in this stack
# (github-actions-runner-permissions.tf) -- no new provider.
#
# WHY A SEPARATE ROLE rather than widening czid-dev-gh-actions-build: that role is
# deliberately scoped to seqtoid-web only (see github-actions-build-role.tf), in BOTH
# its OIDC trust and its ECR resource list. Widening it would let the app-image build
# push workflow images and vice versa. A sibling role keeps each repo able to push only
# its own images, which is the same least-privilege shape already established there.
#
# WHY IT WAS NEEDED: wdl-ci could not push at all. Two independent gaps --
#   1. no dev role trusted repo:*/seqtoid-workflows:*, so the OIDC AssumeRole failed
#      with "Not authorized to perform sts:AssumeRoleWithWebIdentity"; and
#   2. wdl-ci.yml still defaults CI_ACCOUNT_ID to the stale idseq shared-registry
#      account 941377154785 -- the same holdover already called out and retargeted for
#      seqtoid-web in github-actions-build-role.tf. The index-generation ECR repo lives
#      in THIS account (491013321714).
# The net effect was that no WDL workflow image had ever been built and pushed from
# source by CI; images had to be produced by hand.
# =============================================================================

locals {
  # wdl-ci names each image after its workflow dir (workflows/<dir> -> ECR repo <dir>),
  # so the push scope is exactly the set of dirs that have a corresponding dev ECR repo.
  # `legacy-host-filter` is intentionally absent: it has no ECR repository in dev.
  workflows_build_ecr_repos = [
    "amr",
    "benchmark",
    "bulk-download",
    "consensus-genome",
    "diamond",
    "host-genome-generation",
    "index-generation",
    "long-read-mngs",
    "minimap2",
    "phylotree-ng",
    "short-read-mngs",
  ]
}

module "czid_gh_actions_workflows_build" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-workflows-build"
  }
  # Scope the trust to seqtoid-workflows only. subject_ref_pattern="*" supports both the
  # push-triggered build and the on-demand workflow_dispatch image cut; the module's C1
  # guard still DENIES :pull_request subjects (a fork PR can never assume it).
  authorized_github_repos = {
    for org in local.gh_orgs : org => ["seqtoid-workflows"]
  }
  subject_ref_pattern = "*"
}

# Least-privilege ECR push: account-wide auth token (required for `docker login`, cannot
# be resource-scoped) + image push/pull scoped to the workflow image repos only.
data "aws_iam_policy_document" "workflows_build_ecr_push" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushToWorkflowRepos"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      for repo in local.workflows_build_ecr_repos :
      "arn:aws:ecr:${var.region}:${local.account_id}:repository/${repo}"
    ]
  }
}

resource "aws_iam_policy" "workflows_build_ecr_push" {
  name   = "czid-${var.env}-gh-actions-workflows-build-ecr-push"
  policy = data.aws_iam_policy_document.workflows_build_ecr_push.json
}

resource "aws_iam_role_policy_attachment" "workflows_build_ecr_push" {
  role       = module.czid_gh_actions_workflows_build.role.name
  policy_arn = aws_iam_policy.workflows_build_ecr_push.arn
}

output "workflows_build_role_arn" {
  description = "ARN of czid-dev-gh-actions-workflows-build (seqtoid-workflows wdl-ci assumes this to push WDL workflow images to dev ECR)."
  value       = module.czid_gh_actions_workflows_build.role.arn
}
