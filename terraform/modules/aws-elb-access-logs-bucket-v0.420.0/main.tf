locals {
  bucket_name = "${var.project}-${var.env}-${var.service}"

  # account numbers source: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html#access-logging-bucket-permissions
  aws_elb_accounts = {
    "us-east-1"      = "127311923021"
    "us-east-2"      = "033677994240"
    "us-west-1"      = "027434742980"
    "us-west-2"      = "797873946194"
    "ca-central-1"   = "985666609251"
    "eu-central-1"   = "054676820928"
    "eu-west-1"      = "156460612806"
    "eu-west-2"      = "652711504416"
    "eu-west-3"      = "009996457667"
    "eu-north-1"     = "897822967062"
    "ap-northeast-1" = "582318560864"
    "ap-northeast-2" = "600734575887"
    "ap-northeast-3" = "383597477331"
    "ap-southeast-1" = "114774131450"
    "ap-southeast-2" = "783225319266"
    "ap-south-1"     = "718504428378"
    "sa-east-1"      = "507241528517"
  }
}

module "aws-bucket" {
  source = "github.com/chanzuckerberg/cztack//aws-s3-private-bucket?ref=v0.60.1"

  bucket_name   = local.bucket_name
  bucket_policy = data.aws_iam_policy_document.bucket_policy.json
  project       = var.project
  env           = var.env
  service       = var.service
  owner         = var.owner
}

data "aws_iam_policy_document" "bucket_policy" {
  source_policy_documents = var.bucket_policy == "" ? [] : [var.bucket_policy]

  statement {
    sid       = "AWSWriteELBLogs"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.bucket_name}/*"]

    principals {
      type        = "AWS"
      identifiers = formatlist("arn:aws:iam::%s:root", values(local.aws_elb_accounts))
    }

    effect = "Allow"
  }
}
