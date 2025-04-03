# web-acl-regional
This is an official CZI module that configures a regional Web ACL (or "WAF") that's compatible with your region-specific resources. This module has CZI-built monitoring in place so the Security Engineering team can see the effectiveness of this configuration and improve on it.

One thing about this module is that you can insert your own rules--you just have to create your own Web ACL Rule Groups and configure them in the `input_rule_groups` variable. You can even prioritize them by listing them in order like this: `[{highestpriority}, ... , {lowestpriority}]`  
If you just want the CZI baseline, you can ignore the `input_rule_groups` variable and just get monitor the AWS-based recommendations: `rate-based-statement`, `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`, `AWSManagedRulesSQLiRuleSet`. Feel free to read up on [AWS Managed Groups](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html) or ask #help-infosec in the CZI slack to learn more.

> if you want to enforce the CZI baseline rules beyond monitoring--create your logic in your own rule groups and add them in `input_rule_groups`. Their priority will be enforced first.

> Consider the implications of setting names. Creating multiple WAFs with the same tags or same name will result in duplicate buckets. Distinguish between your WAFs carefully!

<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.44 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.44 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_logs_bucket"></a> [logs\_bucket](#module\_logs\_bucket) | github.com/chanzuckerberg/cztack//aws-s3-private-bucket | v0.54.0 |
| <a name="module_panther-s3"></a> [panther-s3](#module\_panther-s3) | git@github.com:chanzuckerberg/shared-infra//terraform/modules/panther-s3-ingest | panther-s3-ingest-v1.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket_notification.bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_wafv2_web_acl.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_account_alias.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_account_alias) | data source |
| [aws_iam_policy_document.waf_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_rulegroup_versions"></a> [aws\_rulegroup\_versions](#input\_aws\_rulegroup\_versions) | Map of managed rule groups to the versions we should use. Commands to retrieve versions here: https://docs.aws.amazon.com/waf/latest/developerguide/waf-using-managed-rule-groups-versions.html | <pre>object({<br>    CommonRuleSet         = optional(string, "Version_1.6"),<br>    KnownBadInputsRuleSet = optional(string, "Version_1.17"),<br>    SQLiRuleSet           = optional(string, "Version_2.0")<br>  })</pre> | `{}` | no |
| <a name="input_czi_baseline_count_rules"></a> [czi\_baseline\_count\_rules](#input\_czi\_baseline\_count\_rules) | Mapping between AWS rulegroup to rules that we should not-block. Empty map or lists means flagged requests are just blocked<br>  For example, if we just want to count the Log4J Header and URI one in the Known Bad Inputs RuleSet, we'd do this:<br>  czi\_baseline\_count\_rules = {<br>    KnownBadInputsRuleSet = ["Log4JRCE\_HEADER", "Log4JRCE\_URIPATH"]<br>  } | <pre>object({<br>    CommonRuleSet         = optional(list(string), []),<br>    KnownBadInputsRuleSet = optional(list(string), []),<br>    SQLiRuleSet           = optional(list(string), []),<br>  })</pre> | `{}` | no |
| <a name="input_enable_panther_ingest"></a> [enable\_panther\_ingest](#input\_enable\_panther\_ingest) | A switch for turning on Panther Ingest--we prioritize this for Production applications | `bool` | `false` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | WAF logged requests will be automatically deleted after this many days. | `number` | `365` | no |
| <a name="input_name"></a> [name](#input\_name) | Custom name for the Web ACL. We suggest making it related to your application for easy searching.<br>    If undefined, it will follow Infra Eng defaults as project-env-service." | `string` | `""` | no |
| <a name="input_requests_per_5_min"></a> [requests\_per\_5\_min](#input\_requests\_per\_5\_min) | Limit on requests per 5-minute period for a single originating IP address. It would be used as a [rate\_limiting\_statement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl.html#rate_based_statement) | `number` | `1000` | no |
| <a name="input_rule_groups"></a> [rule\_groups](#input\_rule\_groups) | List of Rule Group ARNs you want to attach to the WebACL--this implies that the rule groups were created already.<br>    They will have higher priority than the CZI WAF baseline. | <pre>list(object({<br>    arn : string,<br>    name : string,<br>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to the WebACL and its related resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_panther-role"></a> [panther-role](#output\_panther-role) | This role helps CZI's SecEng Team measure the effectiveness of the ACL. Ask #help-infosec in CZI Slack if you have questions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The ACL scope. It can be REGIONAL or CLOUDFRONT |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | The ACL's ARN. This value should be attached to your application [Distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#web_acl_id) |
| <a name="output_web_acl_id"></a> [web\_acl\_id](#output\_web\_acl\_id) | The ACL's ID |
| <a name="output_web_acl_log_bucket"></a> [web\_acl\_log\_bucket](#output\_web\_acl\_log\_bucket) | Your team can find the WebACL Logs at this bucket. The files will be formatted according to [this guide](https://docs.aws.amazon.com/waf/latest/developerguide/logging-s3.html#:~:text=your%20account%20ID.-,Naming%20requirements%20and%20syntax,-Your%20bucket%20names). |
<!-- END -->
