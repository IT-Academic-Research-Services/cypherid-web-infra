# waf-georestriction Terraform Module

This module creates an AWS WAFv2 rule group that blocks traffic from a configurable list of countries using a geo match statement.

## Usage

```hcl
module "waf_georestriction" {
  source = "./modules/waf-georestriction"

  scope                      = "CLOUDFRONT" # or "REGIONAL"
  tags = {
    project = "myproject"
    env     = "prod"
    service = "myservice"
  }
}
```

## Variables

- `scope` (string): Specifies whether this is for CLOUDFRONT or REGIONAL.
- `tags` (map(string)): Tags to use for naming the rule group. Should include `project`, `env`, and `service`.
- `enable_visibility` (bool): Enable CloudWatch metrics and sampled requests for visibility_config. Default is `false`.

## Outputs

- `arn`: The ARN of the WAFv2 rule group.


<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.100.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_wafv2_rule_group.geo_restriction](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_visibility"></a> [enable\_visibility](#input\_enable\_visibility) | Enable CloudWatch metrics and sampled requests for visibility\_config. Default is false. | `bool` | `false` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Specifies whether this is for CLOUDFRONT or REGIONAL. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `object({ project : string, env : string, service : string, owner : string, managedBy : string })` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the WAFv2 rule group. |
| <a name="output_name"></a> [name](#output\_name) | The name of the WAFv2 rule group. |
<!-- END -->