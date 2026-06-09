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

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.log_processing_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.kms_decryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.manage_panther_topic_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.managed_bucket_notifications_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.read_data_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_sns_topic.log_processing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.panther_log_processing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | The S3 Bucket's KMS Key ARN if it has one. | `string` | `""` | no |
| <a name="input_managed_bucket_notifications_enabled"></a> [managed\_bucket\_notifications\_enabled](#input\_managed\_bucket\_notifications\_enabled) | Allow Panther to configure bucket SNS notifications so it can be notified of new logs. [Context](https://docs.panther.com/data-onboarding/data-transports/s3#manual-iam-role-creation-additional-steps) | `bool` | `true` | no |
| <a name="input_role_suffix"></a> [role\_suffix](#input\_role\_suffix) | A unique identifier that will be used as the IAM role suffix. <br>The role will be named `PantherLogProcessingRole-<var.role_suffix>` | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | The S3 Bucket to onboard to Panther for log ingestion (just the name). | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the Panther Ingestion Role | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kms_id"></a> [kms\_id](#output\_kms\_id) | KMS Key ARN for the S3 Bucket |
| <a name="output_role"></a> [role](#output\_role) | The role Panther uses to ingest the logs |
| <a name="output_topic_arn"></a> [topic\_arn](#output\_topic\_arn) | The SNS topic that's used to notify Panther when to pull new events |
<!-- END -->