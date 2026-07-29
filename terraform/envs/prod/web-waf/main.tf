moved {
  from = module.web-service-waf.module.panther-s3
  to   = module.web-service-waf.module.panther-s3[0]
}

locals {
  # CZID-322 (#280): SINGLE SOURCE for the export-control blocked-jurisdiction list — the SAME file the
  # Layer-2 edge Lambda bundles. Change the enforced set THERE (counsel-owned), never here.
  blocked_country_codes = jsondecode(file("${path.module}/../../../export-control/blocked-jurisdictions.json")).blocked_country_codes
}

# CZID-324 (#281): corporate allowlist IP set — known-good corporate egress CIDRs that are ALLOWed
# ahead of the geo-block + AnonymousIpList (false-positive tuning). Env-owned so the CIDRs are
# versioned in this env's config. Defaults to empty ([]) = fully fail-closed, nothing exempted.
resource "aws_wafv2_ip_set" "corporate_allowlist" {
  name               = "${var.tags.project}-${var.tags.env}-corporate-allowlist"
  description        = "Known-good corporate egress IPs allowlisted ahead of the export-control geo/anonymizer blocks - CZID-324."
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.corporate_allowlist_cidrs
  tags               = var.tags
}

module "georestriction-rule" {
  # tflint-ignore: terraform_module_pinned_source
  source = "../../../modules/waf-georestriction-main"

  scope                 = "REGIONAL"
  blocked_country_codes = local.blocked_country_codes
  enable_visibility     = true # CZID-323 (#280): CloudWatch + sampled requests for the IR runbook
  tags                  = var.tags
}

module "web-service-waf" {
  source                         = "../../../modules/web-acl-regional-v3.3.1"
  tags                           = var.tags # TODO: var.tags is deprecated
  enable_panther_ingest          = true
  corporate_allowlist_ip_set_arn = aws_wafv2_ip_set.corporate_allowlist.arn
  rule_groups                    = [{ arn : module.georestriction-rule.arn, name : module.georestriction-rule.name }]
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
