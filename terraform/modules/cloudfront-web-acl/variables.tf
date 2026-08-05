variable "tags" {
  description = "Tags to apply to the Web ACL. project/env/service are also used to derive the ACL name."
  type        = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

variable "name" {
  type        = string
  description = "Custom name for the CloudFront Web ACL. If empty, derived as project-env-service-cloudfront."
  default     = ""
}

variable "count_only" {
  type        = bool
  description = "When true, every managed rule group runs in COUNT (observe-only) for the rollout bake. Default false = enforce (block)."
  default     = false
}

variable "common_ruleset_count_rules" {
  type        = list(string)
  description = "AWSManagedRulesCommonRuleSet sub-rules to run in COUNT (false-positive tuning, e.g. SizeRestrictions_BODY). Empty = block all."
  default     = []
}

variable "known_bad_inputs_count_rules" {
  type        = list(string)
  description = "AWSManagedRulesKnownBadInputsRuleSet sub-rules to run in COUNT (tuning). Empty = block all."
  default     = []
}

variable "anonymous_ip_count_rules" {
  type        = list(string)
  description = "AWSManagedRulesAnonymousIpList sub-rules to run in COUNT (tuning, e.g. HostingProviderIPList catching legit cloud/CI clients). Empty = block all (AnonymousIPList, HostingProviderIPList, TorExitNodeList)."
  default     = []
}
