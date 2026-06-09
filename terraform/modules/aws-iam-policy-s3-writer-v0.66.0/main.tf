locals {
  bucket_arn         = "arn:aws:s3:::${var.bucket_name}"
  bucket_objects_arn = "arn:aws:s3:::${var.bucket_name}${var.bucket_prefix}/*"
  policy_name        = length(var.policy_name) > 0 ? var.policy_name : "${var.project}-${var.service}-${var.env}-s3writer-${var.bucket_name}"
}

data "aws_iam_policy_document" "s3-bucket-writer" {
  statement {
    sid = "WriteToBucket"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]

    resources = [
      local.bucket_arn,
      local.bucket_objects_arn,
    ]
  }
}

resource "aws_iam_policy" "s3-bucket-writer" {
  name_prefix = local.policy_name
  path        = var.policy_path

  policy = data.aws_iam_policy_document.s3-bucket-writer.json
}

resource "aws_iam_role_policy_attachment" "s3-bucket-writer" {
  count = var.role_name != null ? 1 : 0
  role  = var.role_name

  policy_arn = aws_iam_policy.s3-bucket-writer.arn
}

resource "aws_iam_user_policy_attachment" "s3-bucket-writer" {
  count = var.user_name != null ? 1 : 0
  user  = var.user_name

  policy_arn = aws_iam_policy.s3-bucket-writer.arn
}
