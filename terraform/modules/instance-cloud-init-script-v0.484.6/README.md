## Instance Cloud Init Script
Helps generate [cloud-init](https://cloudinit.readthedocs.io/en/latest/) scripts to pass to your instances.

We do a couple of useful things:
- Provision linux user accounts and enable ssh access through CZI's SSH CA.
- Configure DataDog if a key is passed in.
- Coalesce with user's input cloud-init fragments.


## Example Usage:

```hcl
locals {
  test_user = {
    username = "test"
    sudo_enabled = true
  }
}
module "test" {
  source = "modules/init-data"

  users = [
    "${local.test_user}"
  ]
}
```
<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13 |
| <a name="requirement_cloudinit"></a> [cloudinit](#requirement\_cloudinit) | >= 2.3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudinit"></a> [cloudinit](#provider\_cloudinit) | >= 2.3.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudinit_config.script](https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_base64_encode"></a> [base64\_encode](#input\_base64\_encode) | Should the cloudinit script be b64 encoded | `string` | `"true"` | no |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | A datadog key to pass to the agent | `string` | `""` | no |
| <a name="input_env"></a> [env](#input\_env) | n/a | `string` | n/a | yes |
| <a name="input_extra_parts"></a> [extra\_parts](#input\_extra\_parts) | Extra cloud-init parts. See https://www.terraform.io/docs/providers/template/d/cloudinit_config.html | <pre>list(<br>    object({ filename : string, content_type : string, content : string })<br>  )</pre> | `[]` | no |
| <a name="input_gzip"></a> [gzip](#input\_gzip) | Should the cloudinit script be gzipped. | `string` | `"true"` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | n/a | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | n/a | `string` | n/a | yes |
| <a name="input_user_boothook"></a> [user\_boothook](#input\_user\_boothook) | A custom boothook to include as part of the cloudinit process | `string` | `"#!/bin/bash -e\necho 'custom_user_boothook: Nothing to do'\n"` | no |
| <a name="input_user_cloud_config"></a> [user\_cloud\_config](#input\_user\_cloud\_config) | A custom cloud-config (yaml) to include as part of the cloud-init process | `string` | `null` | no |
| <a name="input_user_script"></a> [user\_script](#input\_user\_script) | A custom script to include as part of the cloudinit process | `string` | `"#!/bin/bash -e\necho 'custom_user_script: Nothing to do'\n"` | no |
| <a name="input_users"></a> [users](#input\_users) | A list of unix users to create on the instance. Created user defaults to sudo enabled. | `list(object({ username : string, sudo_enabled : bool }))` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_parts"></a> [parts](#output\_parts) | n/a |
| <a name="output_script"></a> [script](#output\_script) | n/a |
<!-- END -->
