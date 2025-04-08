
# module "czid_sra_export" {
#   source        = "github.com/chanzuckerberg/cztack//aws-s3-private-bucket?ref=v0.73.0"
#   bucket_name   = "czid-sra-export"
#   bucket_policy = data.aws_iam_policy_document.bucket_policy.json
#   env           = var.env
#   owner         = var.owner
#   project       = var.project
#   service       = var.component
# }

# data "aws_iam_policy_document" "bucket_policy" {
#   statement {
#     sid = "NCBIDataDeliveryAccess"
#     actions = [
#       "s3:List*",
#       "s3:Get*",
#       "s3:Put*",
#     ]
#     resources = [
#       "arn:aws:s3:::${module.czid_sra_export.name}",
#       "arn:aws:s3:::${module.czid_sra_export.name}/*"
#     ]

#     principals {
#       type = "AWS"
#       identifiers = [
#         "arn:aws:iam::184059545989:role/NCBI-CSVM-Service",
#         "arn:aws:iam::783971887864:role/NCBI-CSVM-Service"
#       ]
#     }

#     effect = "Allow"
#   }
# }