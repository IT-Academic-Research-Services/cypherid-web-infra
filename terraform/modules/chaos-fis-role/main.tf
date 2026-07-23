# Shared SSOT module: the IAM role AWS FIS assumes to run infra-layer chaos
# experiments (platform-overhaul #794/#797). See deploy/chaos/DESIGN.md.
#
# FIS covers the failures Chaos Mesh cannot reach into: real EC2/node termination, AZ
# power interruption, RDS failover. This role is scoped to exactly that -- terminate/
# describe EC2 instances and read CloudWatch for the experiment stop-condition alarm.
# One definition; each EKS env instantiates it with its own tags.
#
# NARROW BY DESIGN: no create/modify, no IAM, no data-plane. FIS can describe instances
# and terminate them; nothing else. The experiment template (in the env) further scopes
# WHICH instances by tag filter, so this role's terminate permission can only ever be
# exercised against the instances the template selects.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permissions" {
  # checkov:skip=CKV_AWS_356: The only constrainable action here, ec2:TerminateInstances, IS
  # scoped (instance ARN + an ec2:ResourceTag condition below). The remaining wildcard resources
  # are on ec2:DescribeInstances and cloudwatch:DescribeAlarms, which have NO resource-level
  # permissions in IAM -- AWS requires resources=["*"] for them -- so they cannot be narrowed.
  # Read instance state (FIS resolves the tag-filtered target set).
  statement {
    sid       = "DescribeInstances"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
  # The actual fault: terminate a targeted instance. Karpenter re-provisions; the PDB +
  # topology spread keep the app serving. This is the whole point of E4.
  #
  # SCOPED: terminate is allowed ONLY on instances carrying the tag the FIS experiment
  # template targets (var.terminate_target_tag_*). Even if a template were misconfigured,
  # this role physically cannot terminate an instance that is not tagged for chaos -- the
  # IAM condition and the template's target filter are the same tag, kept in lockstep.
  statement {
    sid       = "TerminateTaggedInstances"
    effect    = "Allow"
    actions   = ["ec2:TerminateInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/${var.terminate_target_tag_key}"
      values   = var.terminate_target_tag_values
    }
  }
  # Read the CloudWatch alarm used as the experiment stop-condition (halts the experiment
  # if the ALB starts throwing 5xx -- the fail-safe for the infra layer).
  statement {
    sid       = "ReadStopConditionAlarm"
    effect    = "Allow"
    actions   = ["cloudwatch:DescribeAlarms"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name                 = "${var.cluster_name}-chaos-fis"
  description          = "Role AWS FIS assumes for infra-layer chaos on ${var.cluster_name} (platform-overhaul 797)"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-chaos-fis"
  description = "EC2 describe/terminate + CloudWatch read for FIS chaos on ${var.cluster_name} (platform-overhaul 797)"
  policy      = data.aws_iam_policy_document.permissions.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
