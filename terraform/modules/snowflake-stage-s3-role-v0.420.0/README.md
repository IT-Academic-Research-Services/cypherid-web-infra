<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws-iam-policy-s3-reader"></a> [aws-iam-policy-s3-reader](#module\_aws-iam-policy-s3-reader) | ../aws-iam-policy-s3-reader | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.snowflake](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_policy_document.snowflake-assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_iam_principal"></a> [aws\_iam\_principal](#input\_aws\_iam\_principal) | Snowflake Stage's IAM User, obtained from running the `DESC STAGE` command | `string` | `"arn:aws:iam::713795429718:user/keox-s-ssca5707"` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | n/a | `string` | n/a | yes |
| <a name="input_bucket_prefix"></a> [bucket\_prefix](#input\_bucket\_prefix) | S3 bucket prefix to allow this role to fetch. | `string` | `"/"` | no |
| <a name="input_env"></a> [env](#input\_env) | Env for tagging and naming. See [doc](../README.md#consistent-tagging) | `string` | n/a | yes |
| <a name="input_external_ids"></a> [external\_ids](#input\_external\_ids) | Snowflake Stage's external IDs, obtained from running the `DESC STAGE` command | `list(string)` | `[]` | no |
| <a name="input_max_session_duration_seconds"></a> [max\_session\_duration\_seconds](#input\_max\_session\_duration\_seconds) | The maximum validity of an STS token. | `number` | `3600` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | Owner for tagging and naming. See [doc](../README.md#consistent-tagging) | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Project for tagging and naming. See [doc](../README.md#consistent-tagging) | `string` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | Service for tagging and naming. See [doc](../README.md#consistent-tagging) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | n/a |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | n/a |
<!-- END -->
