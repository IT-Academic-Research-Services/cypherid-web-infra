output "web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "The ACL's ARN. This value should be attached to your application [Distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#web_acl_id)"
}

output "web_acl_id" {
  value       = aws_wafv2_web_acl.main.id
  description = "The ACL's ID"
}

output "scope" {
  value       = "REGIONAL"
  description = "The ACL scope. It can be REGIONAL or CLOUDFRONT"
}

# output "panther-role" {
#   value = var.enable_panther_ingest ? {
#     "arn" : module.panther-s3[0].role.arn,
#     "name" : module.panther-s3[0].role.name,
#     "kms_key_id" : module.panther-s3[0].kms_id,
#     } : {
#     "arn" : "not configured",
#     "name" : "not configured",
#     "kms_key_id" : "not configured",
#   }
#   description = "This role helps CZI's SecEng Team measure the effectiveness of the ACL. Ask #help-infosec in CZI Slack if you have questions."
# }

output "web_acl_log_bucket" {
  value = {
    "bucket" : module.logs_bucket.name,
    "arn" : module.logs_bucket.arn,
    "account_id" : local.account_id,
  }
  description = "Your team can find the WebACL Logs at this bucket. The files will be formatted according to [this guide](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html#:~:text=your%20account%20ID.-,Naming%20requirements%20and%20syntax,-Your%20bucket%20names)."
}
