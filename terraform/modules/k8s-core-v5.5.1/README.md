# k8s-core

Used in combination with eks-cluster to install a core set of services. These include:

* aws-alb-ingress-controller - Provides the ability to put an AWS application load balancer in front of a Kubernetes-hosted service, via annotations on an ingress.
* calico - Network policy implementation for Kubernetes, enforcing rules for what pods can communicate with one another.
* cluster-autoscaler - Auto increases/decreases the number of EC2 worker nodes based on the requested capacity of pods.
* external-dns - Registers services or ingresses on a DNS provider, in our case Route 53.
* datadog-agent - Metrics collector and forwarded to send pod metrics and application metrics to Datadog.
* fluent-bit - Copies pod stdout/stderr logs to central logging currently AWS CloudWatch Logs.
* kiam - Legacy pod to IAM authentication. Comes with both a central server component to lookup/cache IAM access key+secret key+token from AWS, and a per-worker agent component that handles the proxying of the metadata endpoint.
* kube-state-metrics - Collects resource usage of Kubernetes resources.

## Implementation Notes

Due to the nature of the iptable remapping on kiam-agent, the kiam server and agents must be deployed on separate nodes. This is done within eks-cluster by adding taints on small instances intended to host system services
which prevents kiam-agent or any other instance from running on it. The kiam-server here has a toleration for those taints, allowing it to run on those machines. We also use the same system services nodes to run services that we don't want to co-mingle with more volatile app nodes, including the cluster autoscaler.

We have intentionally split this off from the eks-cluster module; combining the 2 modules and having the kubernetes provider dependent on the output of the aws_eks_cluster resource ends up
being problematic since Terraform cannot handle the plans properly. By breaking it into 2 parts that the user has to apply separately, we use the TF state file as a way to decouple the
dependencies that break Terraform.

### Monitor autoscaling

* `kubectl get nodes` to view all the nodes in the cluster. `kubectl get nodes -o=custom-columns=NAME:.metadata.name,TAINTS:.spec.taints` also shows the nodes's taints. Cluster autoscaler marks an unneeded node with `ToBeDeletedByClusterAutoscaler` taint before deleting it.
* `kubectl logs -f <cluster-autoscaler-pod-name> -n kube-system` to read logs.

adoami: force release

<!-- START -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.47.0 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | 3.1.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.47.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws-ssm"></a> [aws-ssm](#module\_aws-ssm) | ../kubernetes-aws-ssm | n/a |
| <a name="module_datadog"></a> [datadog](#module\_datadog) | ./datadog | n/a |
| <a name="module_kiam"></a> [kiam](#module\_kiam) | ./kiam | n/a |
| <a name="module_linkerd"></a> [linkerd](#module\_linkerd) | ./linkerd | n/a |
| <a name="module_nginx_ingress"></a> [nginx\_ingress](#module\_nginx\_ingress) | ./nginx-ingress-controller | n/a |
| <a name="module_nvidia-device-plugin"></a> [nvidia-device-plugin](#module\_nvidia-device-plugin) | ./nvidia-device-plugin | n/a |
| <a name="module_rancher"></a> [rancher](#module\_rancher) | ./rancher | n/a |

## Resources

| Name | Type |
|------|------|
| [helm_release.nodelocaldns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_annotations.gp2_default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/annotations) | resource |
| [kubernetes_namespace.default_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.k8s_core_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_priority_class.k8s-cluster-critical](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/priority_class) | resource |
| [kubernetes_priority_class.k8s-node-critical](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/priority_class) | resource |
| [kubernetes_storage_class.ebs_csi_encrypted_gp3_storage_class](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [kubernetes_service_v1.dns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/service_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_addons"></a> [additional\_addons](#input\_additional\_addons) | An object of additional optional addons for this cluster | <pre>object({<br>    kiam : optional(bool, false)<br>    nginx_ingress : optional(object({<br>      enabled   = optional(bool, false)<br>      namespace = optional(string, "nginx-encrypted-ingress")<br>      version   = optional(string, "4.7.0")<br>    }), {})<br>    linkerd : optional(object({ // How to configure: https://czi.atlassian.net/wiki/spaces/SECENG/pages/2743631992/Linkerd+End+to+End+Encryption+and+Service+Level+Authorization+for+Happy+EKS+services<br>      enabled                     = optional(bool, false)<br>      crd_version                 = optional(string, "1.6.1")<br>      control_plane_version       = optional(string, "1.12.7")<br>      tls_private_cert_param_path = optional(string, "")<br>      tls_private_key_param_path  = optional(string, "")<br>    }), {})<br>    datadog : optional(object({<br>      api_key              = string<br>      agent_tag            = optional(string, "7.53.0")<br>      mute                 = optional(bool, false)<br>      ops_genie_owner_team = string<br>      }), {<br>      api_key              = ""<br>      mute                 = true<br>      ops_genie_owner_team = ""<br>    })<br>    rancher : optional(object(<br>      {<br>        enabled           = optional(bool, true)<br>        provisioner_image = optional(string, "rancher/hyperkube:v1.26.4-rancher2")<br>        cluster_monitoring = optional(object({<br>          enabled       = optional(bool, true)<br>          chart_version = optional(string, "102.0.3+up40.1.2")<br>        }), {})<br>      }<br>    ), {})<br>    nvidia-device-plugin : optional(object(<br>      {<br>        enabled       = optional(bool, false)<br>        chart_version = optional(string, "0.14.1")<br>      }<br>    ), {})<br>  })</pre> | `{}` | no |
| <a name="input_default_namespace"></a> [default\_namespace](#input\_default\_namespace) | Kubernetes namespace for project to use. If blank, uses PROJECT-ENV pattern. | `string` | `""` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | EKS cluster information | <pre>object({<br>    cluster_id : string,<br>    cluster_arn : string,<br>    cluster_endpoint : string,<br>    cluster_ca : string,<br>    cluster_oidc_issuer_url : string,<br>    cluster_version : string,<br>    worker_iam_role_name : string,<br>    worker_security_group : string,<br>    oidc_provider_arn : string,<br>  })</pre> | n/a | yes |
| <a name="input_iam_role_path"></a> [iam\_role\_path](#input\_iam\_role\_path) | IAM Path for the IAM role created for the service. If omitted, defaults to /{eks\_cluster\_id}-k8s-core/ | `string` | `""` | no |
| <a name="input_k8s_core_namespace"></a> [k8s\_core\_namespace](#input\_k8s\_core\_namespace) | Kubernetes namespace to install all the core utilities into. | `string` | `"k8s-core"` | no |
| <a name="input_require_network_policies"></a> [require\_network\_policies](#input\_require\_network\_policies) | Require network policies to enable pod communication. | `string` | `"true"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Standard tags. Typically generated by fogg | <pre>object({<br>    env : string,<br>    owner : string,<br>    project : string,<br>    service : string,<br>    managedBy : string,<br>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_additional_addons"></a> [additional\_addons](#output\_additional\_addons) | n/a |
| <a name="output_aws_ssm_iam_role_name"></a> [aws\_ssm\_iam\_role\_name](#output\_aws\_ssm\_iam\_role\_name) | n/a |
| <a name="output_datadog_agent_hostname"></a> [datadog\_agent\_hostname](#output\_datadog\_agent\_hostname) | n/a |
| <a name="output_default_namespace"></a> [default\_namespace](#output\_default\_namespace) | Default namespace for applications to install into. |
<!-- END -->
