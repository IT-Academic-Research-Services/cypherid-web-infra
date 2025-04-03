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
| <a name="module_es-sg"></a> [es-sg](#module\_es-sg) | terraform-aws-modules/security-group/aws | 4.3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_elasticsearch_domain.es](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticsearch_domain) | resource |
| [aws_elasticsearch_domain_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticsearch_domain_policy) | resource |
| [aws_iam_role.lambda_es_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda_es_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_policy_document.access_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_es_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_policy_arns"></a> [access\_policy\_arns](#input\_access\_policy\_arns) | n/a | `list(any)` | <pre>[<br>  "*"<br>]</pre> | no |
| <a name="input_availability_zone_count"></a> [availability\_zone\_count](#input\_availability\_zone\_count) | Number of Availability Zones for the domain to use with zone\_awareness\_enabled. Defaults to 2. Valid values: 2 or 3. | `number` | `2` | no |
| <a name="input_custom_sg_ids"></a> [custom\_sg\_ids](#input\_custom\_sg\_ids) | List of IDs pointing to custom security groups | `list(string)` | `[]` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | n/a | `string` | n/a | yes |
| <a name="input_ebs_volume_size"></a> [ebs\_volume\_size](#input\_ebs\_volume\_size) | The size of EBS volumes attached to data nodes (in GB). | `number` | `512` | no |
| <a name="input_ebs_volume_type"></a> [ebs\_volume\_type](#input\_ebs\_volume\_type) | The type of EBS volumes attached to data nodes. | `string` | `"gp2"` | no |
| <a name="input_egress_cidrs"></a> [egress\_cidrs](#input\_egress\_cidrs) | n/a | `string` | `"0.0.0.0/0"` | no |
| <a name="input_elasticsearch_version"></a> [elasticsearch\_version](#input\_elasticsearch\_version) | Supported AWS versions can be found at: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html#aes-choosing-version | `string` | `"7.10"` | no |
| <a name="input_env"></a> [env](#input\_env) | n/a | `any` | n/a | yes |
| <a name="input_ingress_cidrs"></a> [ingress\_cidrs](#input\_ingress\_cidrs) | n/a | `string` | `"0.0.0.0/0"` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | n/a | `number` | `2` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | n/a | `string` | `"m4.large.elasticsearch"` | no |
| <a name="input_log_publishing_options"></a> [log\_publishing\_options](#input\_log\_publishing\_options) | List of maps containing configuration of log publishing options. | <pre>object({<br>    cloudwatch_log_group : string<br>  })</pre> | n/a | yes |
| <a name="input_owner"></a> [owner](#input\_owner) | n/a | `any` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `any` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | n/a | `any` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | n/a | `list(any)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_elasticsearch_domain_arn"></a> [elasticsearch\_domain\_arn](#output\_elasticsearch\_domain\_arn) | n/a |
| <a name="output_elasticsearch_domain_name"></a> [elasticsearch\_domain\_name](#output\_elasticsearch\_domain\_name) | n/a |
| <a name="output_elasticsearch_endpoint"></a> [elasticsearch\_endpoint](#output\_elasticsearch\_endpoint) | n/a |
| <a name="output_elasticsearch_lambda_role_arn"></a> [elasticsearch\_lambda\_role\_arn](#output\_elasticsearch\_lambda\_role\_arn) | n/a |
| <a name="output_elasticsearch_security_group_id"></a> [elasticsearch\_security\_group\_id](#output\_elasticsearch\_security\_group\_id) | n/a |
| <a name="output_kibana_endpoint"></a> [kibana\_endpoint](#output\_kibana\_endpoint) | n/a |
<!-- END -->
