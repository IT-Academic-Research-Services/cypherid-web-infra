variable "rule_groups" {
  type = list(object({
    arn : string,
    name : string,
  }))
  description = <<EOF
    List of Rule Group ARNs you want to attach to the WebACL--this implies that the rule groups were created already.
    They will have higher priority than the CZI WAF baseline.
    EOF
  default     = []
}

variable "name" {
  type        = string
  description = <<EOF
    Custom name for the Web ACL. We suggest making it related to your application for easy searching.  
    If undefined, it will follow Infra Eng defaults as project-env-service."
    EOF
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to the WebACL and its related resources."
  type        = map(string)
  default     = {}
}

variable "requests_per_5_min" {
  type        = number
  description = "Limit on requests per 5-minute period for a single originating IP address. It would be used as a [rate_limiting_statement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl.html#rate_based_statement)"
  default     = 1000
}

variable "log_retention_days" {
  type        = number
  description = "WAF logged requests will be automatically deleted after this many days."
  default     = 365
}

variable "aws_rulegroup_versions" {
  type = object({
    CommonRuleSet         = optional(string, "Version_1.6"),
    KnownBadInputsRuleSet = optional(string, "Version_1.17"),
    SQLiRuleSet           = optional(string, "Version_2.0")
  })
  description = <<EOF
  Map of managed rule groups to the versions we should use. Commands to retrieve versions here: https://docs.aws.amazon.com/waf/latest/developerguide/waf-using-managed-rule-groups-versions.html 
  EOF
  default     = {}
}

variable "czi_baseline_count_rules" {
  type = object({
    CommonRuleSet         = optional(list(string), []),
    KnownBadInputsRuleSet = optional(list(string), []),
    SQLiRuleSet           = optional(list(string), []),
  })
  description = <<EOF
  Mapping between AWS rulegroup to rules that we should not-block. Empty map or lists means flagged requests are just blocked
  For example, if we just want to count the Log4J Header and URI one in the Known Bad Inputs RuleSet, we'd do this:
  czi_baseline_count_rules = {
    KnownBadInputsRuleSet = ["Log4JRCE_HEADER", "Log4JRCE_URIPATH"]
  }
  EOF
  default     = {}
}

variable "enable_panther_ingest" {
  type        = bool
  description = "A switch for turning on Panther Ingest--we prioritize this for Production applications"
  default     = false
}

