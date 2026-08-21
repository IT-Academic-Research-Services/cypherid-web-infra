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
  # The workflows artifact bucket this role publishes WDL bundles to (CZID-987). Name mirrors
  # cypherid-workflow-infra/terraform/buckets.tf so the four envs stay parallel:
  # seqtoid-workflows-<env>-<account>. dev -> seqtoid-workflows-dev-491013321714.
  workflows_bucket = "seqtoid-workflows-${var.env}-${local.account_id}"

  # wdl-ci names each image after its workflow dir (workflows/<dir> -> ECR repo <dir>),
  # so the push scope is exactly the set of dirs that have a corresponding dev ECR repo.
  # `legacy-host-filter` is intentionally absent: it has no ECR repository in dev.
  # This list doubles as the S3 bundle-prefix scope below -- the two artifacts of a published
  # version travel together, so one list keeps them from drifting apart.
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

# CZID-987 -- S3 access to the workflows artifact bucket.
#
# The publisher (seqtoid-workflows scripts/publish_workflow_version.py, CZID-971) publishes a version
# as TWO artifacts: an ECR image `:v<semver>` (covered by the policy above) and a WDL bundle at
# s3://<workflows-bucket>/<workflow>-v<version>/. Without S3 the publish job assumed the role, pushed
# nothing, and died on the very first call -- the idempotency check -- with
# "not authorized to perform: s3:ListBucket".
#
# Three operations, each load-bearing:
#   GetObject   read <prefix>/manifest.json to answer "is this version already published?"
#   ListBucket  the guard that REFUSES to overwrite a prefix holding objects but no manifest
#               (bundles copied from upstream predate the publisher). Prefix-scoped: the publisher
#               always lists with Prefix="<workflow>-v<version>/", never bare.
#   PutObject   upload the WDL bundle + manifest
#
# Scoped to the same workflow set as the ECR policy, so this role can only touch prefixes for images
# it is already allowed to push. DeleteObject is deliberately NOT granted: a published version is
# immutable, and the publisher never deletes.
data "aws_iam_policy_document" "workflows_build_s3_publish" {
  statement {
    sid = "ReadWriteWorkflowBundles"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      for workflow in local.workflows_build_ecr_repos :
      "arn:aws:s3:::${local.workflows_bucket}/${workflow}-v*"
    ]
  }
  statement {
    sid       = "ListWorkflowBundlePrefixes"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.workflows_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        for workflow in local.workflows_build_ecr_repos :
        "${workflow}-v*"
      ]
    }
  }
}

resource "aws_iam_policy" "workflows_build_s3_publish" {
  name   = "czid-${var.env}-gh-actions-workflows-build-s3-publish"
  policy = data.aws_iam_policy_document.workflows_build_s3_publish.json
}

resource "aws_iam_role_policy_attachment" "workflows_build_s3_publish" {
  role       = module.czid_gh_actions_workflows_build.role.name
  policy_arn = aws_iam_policy.workflows_build_s3_publish.arn
}

# -----------------------------------------------------------------------------
# Read-only access to the shared reference (taxon index) bucket seqtoid-public-references.
#
# WHY: several WDL workflows default a File input to an object in this bucket, e.g.
# long-read-mngs run.wdl defaults taxon_whitelist to
#   s3://seqtoid-public-references/taxonomy/2020-02-10/respiratory_taxon_whitelist.txt
# (seqtoid-workflows PR 95). wdl-ci runs the workflow's test with miniwdl, and PR 95
# sets MINIWDL__DOWNLOAD_AWSCLI__HOST_CREDENTIALS=true so miniwdl localizes that s3://
# input with a SIGNED `aws s3 cp` using this runner's assumed-role credentials. The
# bucket is PRIVATE (S3 public-access-block on), so the unsigned fallback 403s and the
# signed read requires this role to hold s3:GetObject on the object. Without this grant
# the long-read-mngs wdl-ci job fails localizing the whitelist before it can run.
#
# CROSS-ACCOUNT NOTE: seqtoid-public-references is a single, globally-unique, manually
# created bucket that lives in the idseq-support account 941377154785 (the old shared
# registry account, not migrated when dev was isolated); this role is in the dev account
# 491013321714. Cross-account S3 read is authorized on BOTH sides: an identity policy on
# the caller AND the bucket policy on the bucket. The dev account already reads and
# writes this bucket cross-account today (the dev index-generation lambda writes the
# ncbi-indexes-dev/ prefix with an identity-only grant), which indicates the bucket
# policy already delegates read to the dev account root -- so this identity grant is the
# piece a dev role needs. If an audit shows the bucket policy does NOT delegate to
# 491013321714, an added bucket-policy statement on seqtoid-public-references (owned
# out-of-band in 941377154785, not managed by this stack) is also required.
#
# Read-only and bucket-scoped: GetObject* on every object + ListBucket on the bucket,
# nothing wider. This does NOT make the bucket public and grants no write/delete.
# GetObject* (the wildcard) rather than plain GetObject because the pipeline downloads
# references with s3parcp, which calls s3:GetObjectAttributes (a distinct action) to size
# objects for parallel download; plain GetObject 403s that call. Mirrors the refs job
# policy, which already grants s3:GetObject*.
data "aws_iam_policy_document" "workflows_build_reference_read" {
  statement {
    sid       = "ReadReferenceObjects"
    actions   = ["s3:GetObject*"]
    resources = ["arn:aws:s3:::seqtoid-public-references/*"]
  }
  statement {
    sid       = "ListReferenceBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::seqtoid-public-references"]
  }
}

resource "aws_iam_policy" "workflows_build_reference_read" {
  name   = "czid-${var.env}-gh-actions-workflows-build-reference-read"
  policy = data.aws_iam_policy_document.workflows_build_reference_read.json
}

resource "aws_iam_role_policy_attachment" "workflows_build_reference_read" {
  role       = module.czid_gh_actions_workflows_build.role.name
  policy_arn = aws_iam_policy.workflows_build_reference_read.arn
}

# -----------------------------------------------------------------------------
# KMS access to the workflows artifact bucket's CMK.
#
# The bucket seqtoid-workflows-<env>-<account> is now SSE-KMS encrypted with the customer-managed
# key alias/seqtoid-workflows-<env> (the "seqtoid workflows data tier" key, added by the KMS
# rebrand). The S3 statements above are necessary but no longer sufficient: an SSE-KMS PutObject
# also requires kms:GenerateDataKey on that key, and the publisher's idempotency check (GetObject
# on <prefix>/manifest.json above) reads a KMS-encrypted object, which requires kms:Decrypt.
# Without this the publish job dies on PutObject with "not authorized to perform:
# kms:GenerateDataKey" even though every s3: action it needs is granted -- which is exactly how the
# first post-rebrand publish failed. The key's policy delegates to the account root, so this
# identity grant is the piece the role needs.
#
# Scoped to exactly this one key, resolved via its alias so the four envs stay parallel. Read+write
# data-plane only (GenerateDataKey/Decrypt/DescribeKey); no key administration.
data "aws_kms_key" "workflows" {
  key_id = "alias/seqtoid-workflows-${var.env}"
}

data "aws_iam_policy_document" "workflows_build_kms" {
  statement {
    sid = "UseWorkflowsBucketCmk"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [data.aws_kms_key.workflows.arn]
  }
}

resource "aws_iam_policy" "workflows_build_kms" {
  name   = "czid-${var.env}-gh-actions-workflows-build-kms"
  policy = data.aws_iam_policy_document.workflows_build_kms.json
}

resource "aws_iam_role_policy_attachment" "workflows_build_kms" {
  role       = module.czid_gh_actions_workflows_build.role.name
  policy_arn = aws_iam_policy.workflows_build_kms.arn
}

output "workflows_build_role_arn" {
  description = "ARN of czid-dev-gh-actions-workflows-build (seqtoid-workflows wdl-ci assumes this to push WDL workflow images to dev ECR)."
  value       = module.czid_gh_actions_workflows_build.role.arn
}
