module "web-service-waf" {
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/web-acl-regional?ref=web-acl-regional-v2.3.0"
  tags = {
    project   = var.project
    env       = var.env
    service   = "web"
    owner     = var.owner
    managedBy = var.owner
  }
  enable_panther_ingest = false
  czi_baseline_count_rules = {
    CommonRuleSet = [
      "NoUserAgent_HEADER",
      "UserAgent_BadBots_HEADER",
      "SizeRestrictions_QUERYSTRING",
      "SizeRestrictions_Cookie_HEADER",
      "SizeRestrictions_BODY",
      "SizeRestrictions_URIPATH",
      "EC2MetaDataSSRF_BODY",
      "EC2MetaDataSSRF_COOKIE",
      "EC2MetaDataSSRF_URIPATH",
      "EC2MetaDataSSRF_QUERYARGUMENTS",
      "GenericLFI_QUERYARGUMENTS",
      "GenericLFI_URIPATH",
      "GenericLFI_BODY",
      "RestrictedExtensions_URIPATH",
      "RestrictedExtensions_QUERYARGUMENTS",
      "GenericRFI_QUERYARGUMENTS",
      "GenericRFI_BODY",
      "GenericRFI_URIPATH",
      "CrossSiteScripting_COOKIE",
      "CrossSiteScripting_BODY"
    ]
    KnownBadInputsRuleSet = [
      "JavaDeserializationRCE_BODY",
      "JavaDeserializationRCE_URIPATH",
      "JavaDeserializationRCE_QUERYSTRING",
      "JavaDeserializationRCE_HEADER",
      "Host_localhost_HEADER",
      "PROPFIND_METHOD",
      "ExploitablePaths_URIPATH",
      "Log4JRCE_BODY",
      "Log4JRCE_HEADER"
    ]
    SQLiRuleSet = [
      "SQLiExtendedPatterns_QUERYARGUMENTS",
      "SQLi_QUERYARGUMENTS",
      "SQLi_BODY",
      "SQLi_COOKIE",
      "SQLi_URIPATH",
      "SQLiExtendedPatterns_BODY",
    ]
  }
}

module "snowflake-ingest" {
  source        = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/snowflake-stage-s3-role?ref=v0.420.0"
  project       = var.project
  env           = var.env
  service       = var.component
  owner         = var.owner
  bucket_name   = module.web-service-waf.web_acl_log_bucket.bucket
  bucket_prefix = "/AWSLogs"

  aws_iam_principal = var.snowflake_iam_principal // Defined in Terraform Workplace settings in TFE
  external_ids      = var.snowflake_external_ids
}

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = local.alb_arn
  web_acl_arn  = module.web-service-waf.web_acl_arn
}
