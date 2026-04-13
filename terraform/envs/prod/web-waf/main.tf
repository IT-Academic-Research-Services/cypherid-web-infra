moved {
  from = module.web-service-waf.module.panther-s3
  to   = module.web-service-waf.module.panther-s3[0]
}

module "georestriction-rule" {
  # tflint-ignore: terraform_module_pinned_source
  source = "../../../modules/waf-georestriction-main"

  scope = "REGIONAL"
  tags  = var.tags
}

module "web-service-waf" {
  source                = "../../../modules/web-acl-regional-v3.3.1"
  tags                  = var.tags # TODO: var.tags is deprecated
  enable_panther_ingest = true
  rule_groups           = [{ arn : module.georestriction-rule.arn, name : module.georestriction-rule.name }]
  czi_baseline_count_rules = {
    CommonRuleSet = [
      "NoUserAgent_HEADER",
      "UserAgent_BadBots_HEADER",
      "SizeRestrictions_QUERYSTRING",
      "SizeRestrictions_Cookie_HEADER",
      #"SizeRestrictions_BODY",
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

resource "aws_wafv2_web_acl_association" "web" {
  resource_arn = local.alb_arn
  web_acl_arn  = module.web-service-waf.web_acl_arn
}
