locals {
  # CZI staging account (732052188396) cross-account role that writes transferred data
  # into this bucket. Used by CZI and collaborator Tiago as a data-transfer destination.
  czi_writer_role_arn = "arn:aws:iam::732052188396:role/idseq-staging-batch-job"
}

# Bucket policy granting the CZI staging cross-account role scoped access.
#   - object-level PutObject/GetObject/AbortMultipartUpload/ListMultipartUploadParts are
#     restricted to the samples/ and user_data_exports/ prefixes only;
#   - bucket-level ListBucket/ListBucketMultipartUploads is granted at the bucket root.
# The module merges this document (via source_policy_documents) alongside its own EnforceTLS
# statement (deny when aws:SecureTransport=false) into a single aws_s3_bucket_policy.
data "aws_iam_policy_document" "czi_data_transfer_bucket_policy" {
  statement {
    sid    = "CziPrefixedObjectAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.czi_writer_role_arn]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = [
      "arn:aws:s3:::${var.s3_transfer_destination_bucket}/samples/*",
      "arn:aws:s3:::${var.s3_transfer_destination_bucket}/user_data_exports/*",
    ]
  }

  statement {
    sid    = "CziBucketList"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.czi_writer_role_arn]
    }

    actions = [
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = ["arn:aws:s3:::${var.s3_transfer_destination_bucket}"]
  }
}

# Isolated, hardened data-transfer destination bucket.
#   - public access fully blocked (public_access_block = true -> all 4 sub-settings on);
#   - versioning enabled;
#   - SSE-S3 (AES256) by default -- matches the other dev buckets minted from this module
#     (heatmap batch-jobs / heatmap). No customer-managed CMK: SSE-S3 lets the cross-account
#     CZI role write without also needing a KMS key-policy grant.
module "czi-data-transfer-bucket" {
  source = "../../../modules/aws-s3-private-bucket-v0.104.2" # cztack v0.104.2

  bucket_name = var.s3_transfer_destination_bucket
  env         = var.env
  owner       = var.owner
  project     = var.project
  service     = var.component

  public_access_block = true
  enable_versioning   = true

  bucket_policy = data.aws_iam_policy_document.czi_data_transfer_bucket_policy.json
}
