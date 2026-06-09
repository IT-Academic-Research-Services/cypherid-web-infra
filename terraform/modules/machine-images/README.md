# Machine Images

A simple module for getting the lastest AMI IDs for the base images we build.

Read more about these images [here](/packer).

<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.8 |
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
| [aws_ami.ecs_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_architecture"></a> [architecture](#input\_architecture) | n/a | `string` | `"x86_64"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_czi_amazon2_ecs"></a> [czi\_amazon2\_ecs](#output\_czi\_amazon2\_ecs) | Stable id for a recent build. Updated explicitly to avoid unintended changes. |
<!-- END -->
