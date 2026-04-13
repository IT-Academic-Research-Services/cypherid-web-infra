data "aws_caller_identity" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  panther_account_id = "759041483161"
  bucket_arn         = "arn:aws:s3:::${var.s3_bucket_name}"
}

# IAM roles for log ingestion from an S3 bucket
resource "aws_iam_role" "log_processing_role" {
  name = substr("PantherLogProcessingRole-${var.role_suffix}", 0, 63)

  # Policy that grants an entity permission to assume the role.
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : "sts:AssumeRole",
        Effect : "Allow",
        Principal : {
          AWS : "arn:aws:iam::${local.panther_account_id}:root"
        }
        Condition : {
          Bool : { "aws:SecureTransport" : "true" }
        }
      }
    ]
  })

  tags = merge({
    Application = "Panther"
  }, var.tags)
}


# Provides an IAM role inline policy for reading s3 Data
resource "aws_iam_role_policy" "read_data_policy" {
  name = "ReadData"
  role = aws_iam_role.log_processing_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:GetBucketLocation",
          "s3:ListBucket",
        ],
        Resource : "arn:aws:s3:::${var.s3_bucket_name}"
      },
      {
        Effect : "Allow",
        Action : "s3:GetObject",
        Resource : "arn:aws:s3:::${var.s3_bucket_name}/*"
      }
    ]
  })
}

# Provides an ARN that decrypts ciphertext that was encrypted by a KMS key
resource "aws_iam_role_policy" "kms_decryption" {
  count = var.kms_key_arn != "" ? 1 : 0
  name  = "kmsDecryption"
  role  = aws_iam_role.log_processing_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource : var.kms_key_arn
      }
    ]
  })
}


# Provides an IAM role inline policy for managing panther notification topic
resource "aws_iam_role_policy" "manage_panther_topic_policy" {
  count = var.managed_bucket_notifications_enabled ? 1 : 0
  name  = "ManagePantherTopic"
  role  = aws_iam_role.log_processing_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : "sns:*",
        Resource : aws_sns_topic.log_processing.arn
      }
    ]
  })
}

# Provides an IAM role inline policy for reading and adding notification configuration of a bucket
resource "aws_iam_role_policy" "managed_bucket_notifications_policy" {
  count = var.managed_bucket_notifications_enabled ? 1 : 0
  name  = "GetPutBucketNotifications"
  role  = aws_iam_role.log_processing_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
        ],
        Resource : local.bucket_arn
      }
    ]
  })
}
