locals {
  account_id          = var.aws_accounts.idseq-staging
  s3_bucket_workflows = data.terraform_remote_state.web.outputs.s3_bucket_workflows

  # OIDC trust orgs. During the merge-back transition (CZID-81/26) we trust BOTH the
  # thorvath-slower fork (where active development + CI has been running) AND the live
  # IT-Academic-Research-Services org (now that main + integration are merged back there),
  # so deploys work from either while the team cuts over. The token sub is
  # `repo:<org>/<repo>:...`; the module's :pull_request deny (C1) still applies per role.
  gh_orgs = ["thorvath-slower", "IT-Academic-Research-Services"]
  gh_repos = [
    "cypherid-web-infra",
    "cypherid-workflow-infra",
    "seqtoid-web",
    "seqtoid-workflows",
  ]
}

# The GitHub OIDC identity provider for this account. Both roles below federate
# through it. (Unchanged by the split.)
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  client_id_list  = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------------
# D2 (CZID-26 C1): split the single CI/CD role into two least-privilege roles.
#
#   czid-dev-gh-actions-plan  — READ-ONLY. Assumable from any branch/tag/env
#     (the module's C1 :pull_request deny still applies). Gets AWS-managed
#     ReadOnlyAccess plus a scoped terraform-state READ policy. Used by the
#     `plan` workflow so a plan can render a diff but can never mutate AWS.
#
#   czid-dev-gh-actions-apply — WRITE. Assumable ONLY from refs/heads/main
#     (subject_ref_pattern), so only a merge to main can apply. Keeps the full
#     existing czid_ci_cd deploy policy plus a scoped terraform-state READ/WRITE
#     policy, and the three previously-over-broad managed policies replaced with
#     scoped inline equivalents (D4). Used by the `apply` workflow.
#
# NOTE (workflow follow-up): plan_component_call.yml / apply_component_call.yml
# currently both assume `czid-${env}-gh-actions-executor`. After this applies,
# repoint the plan job to `czid-${env}-gh-actions-plan` and the apply job to
# `czid-${env}-gh-actions-apply`. The old executor role is intentionally kept
# in place until the workflows are cut over, then removed in a follow-up.
# ---------------------------------------------------------------------------

module "czid_gh_actions_plan" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-plan"
  }
  authorized_github_repos = {
    for org in local.gh_orgs : org => local.gh_repos
  }
  # Any branch/tag/env may run a read-only plan; the module still denies
  # :pull_request subjects (C1).
  subject_ref_pattern = "*"
}

module "czid_gh_actions_apply" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-apply"
  }
  authorized_github_repos = {
    for org in local.gh_orgs : org => local.gh_repos
  }
  # The apply job runs under a GitHub Environment (apply_component_call sets
  # `environment: <env>`), so GitHub issues the OIDC token with sub
  # `repo:<org>/<repo>:environment:<env>` -- the git ref is NOT in the sub once an
  # environment is attached, so a `refs/heads/main` pattern never matches and every
  # AssumeRoleWithWebIdentity is denied. Match the environment sub here instead.
  # The "only main may apply" guard now comes from each GitHub Environment's
  # deployment-branch restriction (dev/staging/prod set to deploy only from `main`),
  # NOT the IAM sub. The module's C1 :pull_request deny still applies.
  subject_ref_pattern = "environment:${var.env}"
}

# ---------------------------------------------------------------------------
# Retained legacy executor role. Left in place ONLY so the current workflows
# (which still reference czid-${env}-gh-actions-executor) keep working until the
# plan/apply cutover lands. Remove in the follow-up PR once the workflows point
# at the split roles. Its permissions are unchanged from before this PR.
# ---------------------------------------------------------------------------
module "czid_web_private_gh_actions_executor" {
  source = "../../../modules/aws-iam-role-github-action-v0.104.2" # cztack v0.104.2

  tags = var.tags # TODO: var.tags is deprecated

  role = {
    name = "czid-${var.env}-gh-actions-executor"
  }
  authorized_github_repos = {
    for org in local.gh_orgs : org => local.gh_repos
  }
}

# ===========================================================================
# PLAN role (read-only)
# ===========================================================================

# AWS-managed read-only across services — lets a terraform plan refresh/read
# every resource type without any mutating permission.
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = module.czid_gh_actions_plan.role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Scoped terraform-state READ. The plan job must read the state bucket to build
# a diff. NOTE: this backend uses native S3 lockfile locking
# (`use_lockfile = true`), so there is NO DynamoDB lock table to grant — the
# lock object lives in the same bucket and is covered by the object grants
# below. The staging state bucket is `tfstate-030998640247` (no suffix); the trailing
# `*` on the bucket ARN harmlessly also matches any suffixed variant.
resource "aws_iam_policy" "plan_tfstate_read" {
  name   = "czid-${var.env}-gh-actions-plan-tfstate-read"
  policy = data.aws_iam_policy_document.plan_tfstate_read.json
}

data "aws_iam_policy_document" "plan_tfstate_read" {
  statement {
    sid = "TerraformStateReadList"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::tfstate-${local.account_id}",
      "arn:aws:s3:::tfstate-${local.account_id}-*",
    ]
  }
  statement {
    sid = "TerraformStateReadObjects"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::tfstate-${local.account_id}/*",
      "arn:aws:s3:::tfstate-${local.account_id}-*/*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "plan_tfstate_read" {
  role       = module.czid_gh_actions_plan.role.name
  policy_arn = aws_iam_policy.plan_tfstate_read.arn
}

# ECR-Public authorization token. The eks component's module reads
# `data.aws_ecrpublic_authorization_token` at plan time (to resolve public
# base images), which calls `ecr-public:GetAuthorizationToken` -> requires
# `sts:GetServiceBearerToken`. AWS-managed ReadOnlyAccess does NOT include this
# action, so the read-only plan role was denied. This action is inherently
# read-only: it only vends a short-lived bearer token and grants no standing
# access, and it cannot be resource-scoped (resource must be "*").
resource "aws_iam_policy" "plan_ecr_public_token" {
  name   = "czid-${var.env}-gh-actions-plan-ecr-public-token"
  policy = data.aws_iam_policy_document.plan_ecr_public_token.json
}

data "aws_iam_policy_document" "plan_ecr_public_token" {
  statement {
    sid       = "EcrPublicAuthTokenForPlan"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "plan_ecr_public_token" {
  role       = module.czid_gh_actions_plan.role.name
  policy_arn = aws_iam_policy.plan_ecr_public_token.arn
}

# ===========================================================================
# APPLY role (write) — the real deploy role
# ===========================================================================

# The whole scoped czid_ci_cd deploy policy (defined below), unchanged. This is
# what actually authorizes ECS register/update, ECR push, SSM param read, S3 app
# buckets, batch/states/lambda, iam:PassRole idseq-*, etc.
resource "aws_iam_role_policy_attachment" "apply_ci_cd" {
  role       = module.czid_gh_actions_apply.role.name
  policy_arn = aws_iam_policy.czid_ci_cd.arn
}

# --- PLAN role: decrypt SecureString SSM params (#687) ------------------------
# terraform PLAN reads SecureString SSM parameters (e.g. /idseq-dev-web/db_password via the
# aws-param module). AWS's ReadOnlyAccess grants ssm:GetParameter but deliberately NOT
# kms:Decrypt, so the plan role could not decrypt them and the `db` component failed to plan:
#   AccessDeniedException: ... not authorized to perform: kms:Decrypt on resource: <key>
# Grant decrypt-only (no key management: no Create/Schedule/Disable/Put/Revoke) on this
# account's keys. Read-only in effect -- the plan role still cannot mutate anything.
data "aws_iam_policy_document" "plan_kms_decrypt" {
  statement {
    sid       = "DecryptSecureStringParamsForPlan"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["arn:aws:kms:${var.region}:${local.account_id}:key/*"]
  }
}

resource "aws_iam_policy" "plan_kms_decrypt" {
  name   = "czid-${var.env}-gh-actions-plan-kms-decrypt"
  policy = data.aws_iam_policy_document.plan_kms_decrypt.json
}

resource "aws_iam_role_policy_attachment" "plan_kms_decrypt" {
  role       = module.czid_gh_actions_plan.role.name
  policy_arn = aws_iam_policy.plan_kms_decrypt.arn
}

# --- Infrastructure PROVISIONING grant (#684) ---------------------------------
# The apply role was originally scoped for APP deploys (ECS/ECR/S3/batch, via czid_ci_cd).
# But terraform PROVISIONS the platform: it creates KMS keys, VPC endpoints, RDS, EKS
# nodegroups, WAF ACLs, ACM certs, Route53 records, CloudWatch alarms -- and IAM roles.
# The first time CI could actually assume this role (the CZID-81 trust fix), 19 of 20
# components failed on AccessDenied across ~37 distinct actions (run 29346421280).
#
# PowerUserAccess covers every one of those services. It deliberately EXCLUDES IAM, which
# terraform also needs, so the IAM half is granted explicitly below -- narrowly.
resource "aws_iam_role_policy_attachment" "apply_poweruser" {
  role       = module.czid_gh_actions_apply.role.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# The IAM half PowerUserAccess omits: manage ROLES, POLICIES and INSTANCE PROFILES -- what
# terraform provisions -- and nothing else. No CreateUser / AccessKey / LoginProfile / MFA /
# group / identity-provider / account-alias actions, so this grants no credential surface and
# no way to mint a new principal.
data "aws_iam_policy_document" "apply_iam_provisioning" {
  statement {
    sid    = "ProvisionRolesPoliciesInstanceProfiles"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy", "iam:UntagPolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
      "iam:CreateServiceLinkedRole",
      "iam:PassRole",
    ]
    # Scoped to this account's roles / policies / instance profiles. Terraform derives many
    # of these names at plan time (eks, batch, lambda, service-linked), so a name-prefix
    # allowlist would break provisioning; constraining by ACCOUNT + RESOURCE TYPE keeps the
    # grant real while structurally excluding users, groups and identity providers -- which
    # the action list already omits. Belt and braces.
    resources = [
      "arn:aws:iam::${local.account_id}:role/*",
      "arn:aws:iam::${local.account_id}:policy/*",
      "arn:aws:iam::${local.account_id}:instance-profile/*",
    ]
  }

  # ANTI-ESCALATION. The apply role must never rewrite the CI identity itself -- neither the
  # gh-actions roles nor the policies ATTACHED to them (widening czid_ci_cd would widen this
  # very role just as surely as attaching AdministratorAccess to it). Denying the WRITE verbs
  # only (reads stay allowed, so terraform refresh still works) means any change to the CI
  # identity must be applied out-of-band with admin creds -- exactly as the CZID-81 bootstrap
  # was. Deliberate: `access-management` self-changes are expected to fail in CI.
  statement {
    sid    = "DenyCIIdentitySelfModification"
    effect = "Deny"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:CreatePolicy", "iam:DeletePolicy",
      "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy", "iam:UntagPolicy",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/czid-${var.env}-gh-actions-*",
      "arn:aws:iam::${local.account_id}:policy/czid-${var.env}-gh-actions-*",
      "arn:aws:iam::${local.account_id}:policy/czid-${var.env}-ci-cd",
    ]
  }
}

resource "aws_iam_policy" "apply_iam_provisioning" {
  name   = "czid-${var.env}-gh-actions-apply-iam-provisioning"
  policy = data.aws_iam_policy_document.apply_iam_provisioning.json
}

resource "aws_iam_role_policy_attachment" "apply_iam_provisioning" {
  role       = module.czid_gh_actions_apply.role.name
  policy_arn = aws_iam_policy.apply_iam_provisioning.arn
}

# NOTE (#684): AWS caps a role at 10 managed policies (PoliciesPerRole). Attaching
# PowerUserAccess + the IAM-provisioning policy blew that quota, so the attachments below
# were removed: PowerUserAccess is a strict SUPERSET of each (it grants every service except
# IAM/Organizations). The policies themselves remain defined but unattached. What the apply
# role now carries: PowerUserAccess (all services), apply_iam_provisioning (the IAM half
# PowerUser omits, scoped + with the self-escalation Deny), IAMReadOnlyAccess (IAM reads,
# which PowerUser excludes), plus czid_ci_cd and tfstate_rw retained deliberately.
resource "aws_iam_role_policy_attachment" "apply_iam_read" {
  role       = module.czid_gh_actions_apply.role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

# --- Scoped terraform-state READ/WRITE ----------------------------------------
# The apply job reads AND writes state (+ the native S3 lock object). Same bucket
# scoping caveat as the plan role: native lockfile, no DynamoDB.
resource "aws_iam_policy" "apply_tfstate_rw" {
  name   = "czid-${var.env}-gh-actions-apply-tfstate-rw"
  policy = data.aws_iam_policy_document.apply_tfstate_rw.json
}

data "aws_iam_policy_document" "apply_tfstate_rw" {
  statement {
    sid = "TerraformStateList"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::tfstate-${local.account_id}",
      "arn:aws:s3:::tfstate-${local.account_id}-*",
    ]
  }
  statement {
    sid = "TerraformStateReadWriteAndLock"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject", # native lockfile removal on unlock
    ]
    resources = [
      "arn:aws:s3:::tfstate-${local.account_id}/*",
      "arn:aws:s3:::tfstate-${local.account_id}-*/*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "apply_tfstate_rw" {
  role       = module.czid_gh_actions_apply.role.name
  policy_arn = aws_iam_policy.apply_tfstate_rw.arn
}

# --- D4: scoped CloudWatch Logs (replaces CloudWatchFullAccess) ----------------
# The old CloudWatchFullAccess was near-superuser over metrics, alarms, logs, and
# dashboards. Deploys only need to create/read the app's log groups/streams and
# put log events; cloudwatch:PutMetricData is already granted in czid_ci_cd.
resource "aws_iam_policy" "apply_cw_logs" {
  name   = "czid-${var.env}-gh-actions-apply-cw-logs"
  policy = data.aws_iam_policy_document.apply_cw_logs.json
}

data "aws_iam_policy_document" "apply_cw_logs" {
  statement {
    sid = "CloudWatchLogsWrite"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:ListTagsForResource",
    ]
    resources = [
      "arn:aws:logs:*:${local.account_id}:log-group:idseq-${var.env}-*",
      "arn:aws:logs:*:${local.account_id}:log-group:idseq-${var.env}-*:*",
      "arn:aws:logs:*:${local.account_id}:log-group:/ecs/idseq-${var.env}-*",
      "arn:aws:logs:*:${local.account_id}:log-group:/ecs/idseq-${var.env}-*:*",
      "arn:aws:logs:*:${local.account_id}:log-group:ecs-logs-${var.env}-*",
      "arn:aws:logs:*:${local.account_id}:log-group:ecs-logs-${var.env}-*:*",
    ]
  }
  statement {
    sid = "CloudWatchLogsDescribe"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    # Describe* only supports resource-level scoping to log-group; keep it
    # narrowed to the idseq-* / ecs-logs-* groups.
    resources = [
      "arn:aws:logs:*:${local.account_id}:log-group:idseq-${var.env}-*",
      "arn:aws:logs:*:${local.account_id}:log-group:idseq-${var.env}-*:*",
      "arn:aws:logs:*:${local.account_id}:log-group:/ecs/idseq-${var.env}-*",
      "arn:aws:logs:*:${local.account_id}:log-group:/ecs/idseq-${var.env}-*:*",
      "arn:aws:logs:*:${local.account_id}:log-group:ecs-logs-${var.env}-*",
      "arn:aws:logs:*:${local.account_id}:log-group:ecs-logs-${var.env}-*:*",
    ]
  }
}

# --- D4: scoped ECR (replaces AmazonEC2ContainerRegistryPowerUser) -------------
# The deploy logs in to ECR and pushes/pulls the app image. GetAuthorizationToken
# has no resource scoping (must be "*"); the push/pull layer actions are scoped
# to the app's ECR repositories.
resource "aws_iam_policy" "apply_ecr" {
  name   = "czid-${var.env}-gh-actions-apply-ecr"
  policy = data.aws_iam_policy_document.apply_ecr.json
}

data "aws_iam_policy_document" "apply_ecr" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken cannot be resource-scoped
  }
  statement {
    sid = "EcrPushPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
    ]
    resources = [
      "arn:aws:ecr:*:${local.account_id}:repository/idseq-*",
      "arn:aws:ecr:*:${local.account_id}:repository/czid-*",
    ]
  }
}

# --- D4: scoped SSM param read (replaces AmazonSSMManagedInstanceCore) ----------
# The deploy reads app config/secrets from SSM Parameter Store (Chamber uses the
# /idseq-<env>-* path). AmazonSSMManagedInstanceCore was for EC2 instance mgmt
# (ssmmessages/ec2messages) — the CI role is not an instance and never needs it.
# NOTE: czid_ci_cd already grants ssm:GetParameters / GetParametersByPath /
# DescribeParameters / PutParameter on /idseq-<env>-*; this adds the plain
# GetParameter (singular) that some Chamber/SDK code paths call.
resource "aws_iam_policy" "apply_ssm_params" {
  name   = "czid-${var.env}-gh-actions-apply-ssm-params"
  policy = data.aws_iam_policy_document.apply_ssm_params.json
}

data "aws_iam_policy_document" "apply_ssm_params" {
  statement {
    sid = "SsmParamRead"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameterHistory",
    ]
    resources = [
      "arn:aws:ssm:*:${local.account_id}:parameter/idseq-${var.env}-*",
    ]
  }
}

# ===========================================================================
# The scoped CI/CD deploy policy (UNCHANGED — carried over verbatim from the
# original executor role; do NOT trim any statement here, it is the proven set
# of deploy permissions). Attached to the APPLY role above.
# ===========================================================================
resource "aws_iam_policy" "czid_ci_cd" {
  name   = "czid-${var.env}-ci-cd"
  policy = data.aws_iam_policy_document.ci_cd_policy_document.json
}

data "aws_iam_policy_document" "ci_cd_policy_document" {
  statement {
    actions = [
      "s3:List*",
      "s3:Get*"
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_public_references}",
      "arn:aws:s3:::${var.s3_bucket_public_references}/*",
      "arn:aws:s3:::czid-public-references",
      "arn:aws:s3:::czid-public-references/*",
      "arn:aws:s3:::aegea-batch-jobs-${local.account_id}",
      "arn:aws:s3:::aegea-batch-jobs-${local.account_id}/*",
      "arn:aws:s3:::idseq-${var.env}-*",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}",
      "arn:aws:s3:::${var.s3_bucket_idseq_bench}/*",
    ]
  }

  statement {
    actions = [
      "s3:List*",
      "s3:GetObject*",
      "s3:PutObject*"
    ]

    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}",   # TODO: Is this necessary?
      "arn:aws:s3:::${var.s3_bucket_samples}/*", # TODO: Is this necessary?
      "arn:aws:s3:::${local.s3_bucket_workflows}",
      "arn:aws:s3:::${local.s3_bucket_workflows}/*",
      "arn:aws:s3:::tfstate-${local.account_id}",
      "arn:aws:s3:::tfstate-${local.account_id}/*",
      "arn:aws:s3:::idseq-${var.env}-heatmap",
      "arn:aws:s3:::idseq-${var.env}-heatmap/*"
    ]
  }

  statement {
    actions = [
      "batch:*",
      "events:*",
      "states:*"
    ]

    resources = ["*"]
  }

  statement {
    actions = ["lambda:*"]

    resources = [
      "arn:aws:lambda:*:${local.account_id}:function:idseq-*",
      "arn:aws:lambda:*:${local.account_id}:function:cloudwatch-alerting-*"
    ]
  }
  statement {
    actions = ["secretsmanager:*"]

    resources = [
      "arn:aws:secretsmanager:*:${local.account_id}:secret:idseq/*"
    ]
  }
  statement {
    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:role/idseq-${var.env}-*",
      "arn:aws:iam::${local.account_id}:role/idseq-swipe-${var.env}-*",
      "arn:aws:iam::${local.account_id}:role/idseq-web-*"
    ]
  }

  statement {
    actions = [
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CopyImage",
      "ec2:CreateImage",
      "ec2:CreateKeypair",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSnapshot",
      "ec2:DeleteVolume",
      "ec2:DeregisterImage",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeRegions",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSnapshots",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
      "ec2:GetPasswordData",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySnapshotAttribute",
      "ec2:RegisterImage",
      "ec2:RunInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]
  }

  statement {
    sid = "UpdateLaunchTemplatePermissions"

    actions = [
      "ec2:CreateLaunchTemplate*",
      "ec2:DescribeLaunchTemplate*",
      "ec2:DeleteLaunchTemplate*",
      "ec2:ModifyLaunchTemplate"
    ]

    resources = ["*"]
  }

  statement {
    actions = ["sqs:*"]

    resources = [
      "arn:aws:sqs:*:${local.account_id}:idseq-${var.env}-*",
      "arn:aws:sqs:*:${local.account_id}:idseq-swipe-*"
    ]
  }

  statement {
    actions = [
      "ssm:DescribeParameters"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
      "ssm:PutParameter"
    ]

    resources = [
      "arn:aws:ssm:*:${local.account_id}:parameter/idseq-${var.env}-*"
    ]
  }
  statement {
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:RunTask"
    ]

    resources = [
      "arn:aws:ecs:*:${local.account_id}:service/${var.env}/*",
      "arn:aws:ecs:*:${local.account_id}:service/idseq-${var.env}-ecs/*",
      "arn:aws:ecs:*:${local.account_id}:task-definition/idseq-${var.env}-web:*",
      "arn:aws:ecs:*:${local.account_id}:task/idseq-${var.env}-ecs/*",
      "arn:aws:ecs:*:${local.account_id}:task/${var.env}/*",
    ]
  }

  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition"
    ]

    resources = ["*"]
  }

  statement {
    actions = ["cloudwatch:PutMetricData"]

    resources = ["*"]
  }

  statement {
    actions = ["kms:Describe*"]

    resources = ["*"]
  }
}
