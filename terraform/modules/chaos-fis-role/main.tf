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
  # Read instance state (FIS resolves the tag-filtered target set).
  statement {
    sid       = "DescribeInstances"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
  # The actual fault: terminate a targeted instance. Karpenter re-provisions; the PDB +
  # topology spread keep the app serving. This is the whole point of E4.
  statement {
    sid       = "TerminateInstances"
    effect    = "Allow"
    actions   = ["ec2:TerminateInstances"]
    resources = ["*"]
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
