# Used by both On Call and Comp Bio Roles
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# On Call Role/Instance Profile 

resource "aws_iam_role" "on_call" {
  name               = "czid-on-call"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "Allows IDSeq Developers to perform on call maintenence tasks from EC2 instances"
}

resource "aws_iam_role_policy_attachment" "on_call_poweruser" {
  role       = aws_iam_role.on_call.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_instance_profile" "on_call" {
  name = "czid-on-call"
  role = aws_iam_role.on_call.name
}

# Comp Bio Role/Instance Profile 

resource "aws_iam_role" "comp_bio" {
  name               = "czid-comp-bio"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "Allows IDSeq Computational Biologists to perform analysis on production data on EC2 instances"
}

resource "aws_iam_role_policy_attachment" "comp_bio_managed_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/IAMReadOnlyAccess",
    "arn:aws:iam::${var.aws_account_id}:policy/OrgwideSecretsReader",
  ])

  role       = aws_iam_role.comp_bio.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "comp_bio_policy" {
  statement {
    sid = "PublicReferencesReadOnlyAccess"
    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    resources = [
      "arn:aws:s3:::czid-public-references",
      "arn:aws:s3:::czid-public-references/*",
    ]
  }

  statement {
    sid = "SamplesReadOnlyAccess"
    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_samples}",
      "arn:aws:s3:::${var.s3_bucket_samples}/*",
    ]
  }

  statement {
    sid       = "WorkspaceWriteAccess"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${var.s3_bucket_samples}/comp-bio-workspace/*"]
  }
}

resource "aws_iam_role_policy" "comp_bio" {
  role   = aws_iam_role.comp_bio.name
  policy = data.aws_iam_policy_document.comp_bio_policy.json
}

resource "aws_iam_instance_profile" "comp_bio" {
  name = "czid-comp-bio"
  role = aws_iam_role.comp_bio.name
}

# Packer Instance Instance Profile, based on https://aws.amazon.com/blogs/mt/creating-packer-images-using-system-manager-automation/

data "aws_iam_policy_document" "packer_instance_assume_role" {
  statement {
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "ssm.amazonaws.com",
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "packer_instance" {
  name               = "czid-packer-instance"
  assume_role_policy = data.aws_iam_policy_document.packer_instance_assume_role.json
  description        = "Assumed by packer managed instances for automated AMI creation"
}

resource "aws_iam_role_policy_attachment" "packer_instance_ssm_automation" {
  role       = aws_iam_role.packer_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

data "aws_iam_policy_document" "packer_instance_policy" {
  statement {
    sid       = "AllowGettingInstanceProfiles"
    actions   = ["iam:GetInstanceProfile"]
    resources = ["arn:aws:iam::*:instance-profile/*"]
  }

  statement {
    sid = "AllowLogging"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
    ]
    resources = ["arn:aws:logs:*:*:log-group:*"]
  }

  statement {
    sid = "AllowSSM"
    actions = [
      "ec2:DescribeInstances",
      "ec2:CreateKeyPair",
      "ec2:DescribeRegions",
      "ec2:DescribeVolumes",
      "ec2:DescribeSubnets",
      "ec2:DeleteKeyPair",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "packer_instance" {
  role   = aws_iam_role.packer_instance.name
  policy = data.aws_iam_policy_document.packer_instance_policy.json
}

data "aws_iam_policy_document" "packer_instance_pass_role" {
  statement {
    sid       = "AllowPassRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.packer_instance.arn]
  }
}

resource "aws_iam_role_policy" "packer_instance_pass_role" {
  role   = aws_iam_role.packer_instance.name
  policy = data.aws_iam_policy_document.packer_instance_pass_role.json
}

resource "aws_iam_instance_profile" "packer_instance" {
  name = "czid-packer-instance"
  role = aws_iam_role.packer_instance.name
}
