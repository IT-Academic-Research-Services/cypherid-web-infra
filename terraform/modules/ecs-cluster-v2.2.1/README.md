# ECS Cluster

This module creates an autoscaling group whose members form an ECS cluster.

There is currently no autoscaling here (and probably never will be because
we will just use Fargate when its available.).

## Example

Below example will create an ECS cluster in a VPC managed by our stack.

You'll note that there is a fair amout of boilerplate, but much of it is auto-managed by fogg.

```
module "ecs" {
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/ecs-cluster?ref=ecs-cluster-v2.3.0"

  servers             = 2
  instance_type       = "m5.large"
  ssh_key_name        = "infra-ssh-key"

  # Variables set by fogg. If not using fogg, set them yourself.
  region              = "${var.region}"
  project             = "${var.project}"
  env                 = "${var.env}"

  # Also managed by fogg.
  vpc_id              = "${data.terraform_remote_state.cloud-env.outputs.vpc_id}"
  subnets             = "${data.terraform_remote_state.cloud-env.outputs.private_subnets}"
  allowed_cidr_blocks = ["${data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block}"]
}

```

<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_attach-logs"></a> [attach-logs](#module\_attach-logs) | github.com/chanzuckerberg/cztack//aws-iam-policy-cwlogs | v0.43.1 |
| <a name="module_images"></a> [images](#module\_images) | ../machine-images | n/a |
| <a name="module_logs"></a> [logs](#module\_logs) | github.com/chanzuckerberg/cztack//aws-cloudwatch-log-group | v0.43.1 |
| <a name="module_orgwide-secrets"></a> [orgwide-secrets](#module\_orgwide-secrets) | ../aws-iam-policy-orgwide-secrets | n/a |
| <a name="module_profile"></a> [profile](#module\_profile) | github.com/chanzuckerberg/cztack//aws-iam-instance-profile | v0.60.0 |
| <a name="module_sg"></a> [sg](#module\_sg) | terraform-aws-modules/security-group/aws | 4.3.0 |
| <a name="module_user_data"></a> [user\_data](#module\_user\_data) | ../instance-cloud-init-script | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.graceful_shutdown_asg_hook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_schedule.ecs-down](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule) | resource |
| [aws_autoscaling_schedule.ecs-up](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule) | resource |
| [aws_ecs_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_iam_policy.ecs-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.attach-ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [random_id.rand](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.ecs-policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [template_file.boothook](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.user_data](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_user_data_script"></a> [additional\_user\_data\_script](#input\_additional\_user\_data\_script) | A script that gets executed at ec2 machine boot time. | `string` | `""` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | n/a | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_ami"></a> [ami](#input\_ami) | Specify which ECS AMI image you want to run. Otherwise uses the CZI ECS AMI. | `string` | `""` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | n/a | `bool` | `false` | no |
| <a name="input_cluster_asg_rolling_interval_hours"></a> [cluster\_asg\_rolling\_interval\_hours](#input\_cluster\_asg\_rolling\_interval\_hours) | If set to a positive value, this will cycle an instance every N hours, replacing it with a new one. | `string` | `0` | no |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | A datadog api key to enable the datadog agent on the instance | `string` | `""` | no |
| <a name="input_docker_storage_size"></a> [docker\_storage\_size](#input\_docker\_storage\_size) | EBS Volume size in Gib that the ECS Instance uses for Docker images and metadata | `string` | `"100"` | no |
| <a name="input_ec2_extra_tags"></a> [ec2\_extra\_tags](#input\_ec2\_extra\_tags) | Extra tags to apply to EC2 instances in the cluster. | `map(string)` | `{}` | no |
| <a name="input_ecs_cluster_name"></a> [ecs\_cluster\_name](#input\_ecs\_cluster\_name) | override the default cluster name | `string` | `""` | no |
| <a name="input_env"></a> [env](#input\_env) | n/a | `string` | n/a | yes |
| <a name="input_heartbeat_timeout"></a> [heartbeat\_timeout](#input\_heartbeat\_timeout) | Heartbeat Timeout setting for how long it takes for the graceful shutodwn hook takes to timeout. This is useful when deploying clustered applications that benifit from having a deploy between autoscaling create/destroy actions. Defaults to 180 | `string` | `"180"` | no |
| <a name="input_iam_path"></a> [iam\_path](#input\_iam\_path) | IAM path, this is useful when creating resources with the same name across multiple regions. Defaults to / | `string` | `"/"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | n/a | `string` | n/a | yes |
| <a name="input_log_retention_in_days"></a> [log\_retention\_in\_days](#input\_log\_retention\_in\_days) | N of days you want to retain log events. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, and 0. | `number` | `0` | no |
| <a name="input_max_servers"></a> [max\_servers](#input\_max\_servers) | Maximum number of instances for the cluster. Must be at least var.min\_servers + 1. | `number` | `2` | no |
| <a name="input_min_servers"></a> [min\_servers](#input\_min\_servers) | Minimum number of instances for the cluster. | `number` | `1` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | n/a | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | n/a | yes |
| <a name="input_registrator_image"></a> [registrator\_image](#input\_registrator\_image) | Image to use when deploying registrator agent, defaults to the gliderlabs registrator:latest image | `string` | `"gliderlabs/registrator:latest"` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | A list of Security group IDs to apply to the launch configuration | `list(string)` | `[]` | no |
| <a name="input_service"></a> [service](#input\_service) | n/a | `string` | `"ecs"` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | n/a | `string` | n/a | yes |
| <a name="input_ssh_users"></a> [ssh\_users](#input\_ssh\_users) | A list of ssh users that will get created on each ec2 instance. Defaults to sudo enabled. | `list(object({ username : string, sudo_enabled : bool }))` | `[]` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of subnets in which to deploy the cluster. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | n/a |
| <a name="output_arn"></a> [arn](#output\_arn) | n/a |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | n/a |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_container_instance_role_arn"></a> [container\_instance\_role\_arn](#output\_container\_instance\_role\_arn) | The ec2 role run in the container instances. If using ECR, authorize this role for read access. |
| <a name="output_ecs"></a> [ecs](#output\_ecs) | n/a |
| <a name="output_logs_group_arn"></a> [logs\_group\_arn](#output\_logs\_group\_arn) | n/a |
| <a name="output_logs_group_name"></a> [logs\_group\_name](#output\_logs\_group\_name) | n/a |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | n/a |
<!-- END -->
