locals {
  bucket_arn             = "arn:aws:s3:::${var.bucket_name}"
  bucket_arn_with_prefix = "${local.bucket_arn}${var.bucket_prefix}/*"
  policy_name            = length(var.policy_name) > 0 ? var.policy_name : "${var.project}-${var.service}-${var.env}-s3reader-${var.bucket_name}"
}

data "aws_iam_policy_document" "s3-bucket-reader" {
  statement {
    sid = "ReadFromBucket"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = [local.bucket_arn]
  }

  statement {
    sid = "ReadFromBucketKeys"

    actions = [
      "s3:Get*",
      "s3:List*",
    ]

    resources = [local.bucket_arn_with_prefix]
  }
}

resource "aws_iam_policy" "s3-bucket-reader" {
  name_prefix = local.policy_name
  path        = var.policy_path

  policy = data.aws_iam_policy_document.s3-bucket-reader.json
}

resource "aws_iam_role_policy_attachment" "s3-bucket-reader" {
  count = var.role_name != null ? 1 : 0
  role  = var.role_name

  policy_arn = aws_iam_policy.s3-bucket-reader.arn
}

resource "aws_iam_user_policy_attachment" "s3-bucket-reader" {
  count = var.user_name != null ? 1 : 0
  user  = var.user_name

  policy_arn = aws_iam_policy.s3-bucket-reader.arn
}
