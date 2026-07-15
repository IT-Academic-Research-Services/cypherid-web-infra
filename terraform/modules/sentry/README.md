<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >1.14.1 |
| <a name="requirement_sentry"></a> [sentry](#requirement\_sentry) | 0.14.13 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_sentry"></a> [sentry](#provider\_sentry) | 0.14.13 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_sentry-ssm-params"></a> [sentry-ssm-params](#module\_sentry-ssm-params) | github.com/chanzuckerberg/cztack//aws-ssm-params-writer | v0.104.2 |

## Resources

| Name | Type |
|------|------|
| [sentry_key.seqtoid_web_backend](https://registry.terraform.io/providers/jianyuan/sentry/0.14.13/docs/resources/key) | resource |
| [sentry_key.seqtoid_web_frontend](https://registry.terraform.io/providers/jianyuan/sentry/0.14.13/docs/resources/key) | resource |
| [sentry_project.seqtoid_web_backend](https://registry.terraform.io/providers/jianyuan/sentry/0.14.13/docs/resources/project) | resource |
| [sentry_project.seqtoid_web_frontend](https://registry.terraform.io/providers/jianyuan/sentry/0.14.13/docs/resources/project) | resource |
| [sentry_team.seqtoid_env](https://registry.terraform.io/providers/jianyuan/sentry/0.14.13/docs/resources/team) | resource |
| [sentry_organization.seqtoid](https://registry.terraform.io/providers/jianyuan/sentry/0.14.13/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env"></a> [env](#input\_env) | n/a | `string` | n/a | yes |
| <a name="input_organization"></a> [organization](#input\_organization) | n/a | `string` | n/a | yes |
| <a name="input_owner"></a> [owner](#input\_owner) | n/a | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END -->