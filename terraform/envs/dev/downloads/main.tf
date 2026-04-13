data "aws_iam_policy_document" "downloads-assume-role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "downloads" {
  name               = "idseq-downloads-development"
  description        = "task role for downloads task in development environment"
  assume_role_policy = data.aws_iam_policy_document.downloads-assume-role.json
}

module "downloads_iam_policy" {
  source = "../../../modules/aws-iam-policy-s3-writer-v0.66.0"

  bucket_name   = var.s3_bucket_samples
  bucket_prefix = ""

  env       = var.env
  owner     = var.owner
  project   = var.project
  role_name = aws_iam_role.downloads.name
  service   = var.component
}

resource "aws_iam_role" "downloads_v1" {
  name               = "czi-infectious-disease-downloads-development"
  description        = "downloads v1 task role for downloads task"
  assume_role_policy = data.aws_iam_policy_document.downloads-assume-role.json
}

module "downloads_v1_iam_policy" {
  source = "../../../modules/aws-iam-policy-s3-writer-v0.66.0"

  bucket_name   = var.s3_bucket_samples_v1
  bucket_prefix = ""

  env       = var.env
  owner     = var.owner
  project   = var.project
  role_name = aws_iam_role.downloads_v1.name
  service   = var.component
}

// The "czi-infectious-disease-downloads-development" task role also needs access to the old samples bucket to read the src_urls of an ECS bulk download.
module "downloads_v1_iam_policy_for_old_samples_bucket" {
  source = "../../../modules/aws-iam-policy-s3-writer-v0.66.0"

  bucket_name   = var.s3_bucket_samples
  bucket_prefix = ""

  env       = var.env
  owner     = var.owner
  project   = var.project
  role_name = aws_iam_role.downloads_v1.name
  service   = var.component
}
