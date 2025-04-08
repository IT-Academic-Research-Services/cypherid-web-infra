locals {
  karpenter_discovery             = { "karpenter.sh/discovery" = local.cluster_name }
  karpenter_discovery_per_cluster = { "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name }
  fluentbit_log_group_name        = "/aws/eks/${local.cluster_name}/aws-fluentbit-logs"
  default_exclude_list = [
    "/var/log/containers/aws-for-fluent-bit*",
    "/var/log/containers/aws-node*",
    "/var/log/containers/kube-proxy*",
    "/var/log/containers/scraper-collector*"
  ]
  exclude_list = distinct(concat(local.default_exclude_list, var.addons.fluentbit_exclude_paths))
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us-east-1
}


data "aws_iam_policy_document" "fluentbit_policy" {
  statement {
    sid       = "FluentbitCWLogs"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
      "logs:PutLogEvents"
    ]
  }
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.19.0"

  observability_tag = null // Do not deploy observability cloudformation stack

  cluster_name      = module.cluster.cluster_name
  cluster_endpoint  = module.cluster.cluster_endpoint
  oidc_provider_arn = module.cluster.oidc_provider_arn
  cluster_version   = module.cluster.cluster_version

  enable_argocd = var.addons.enable_argocd
  argocd        = var.addons.argocd_config

  enable_aws_cloudwatch_metrics         = var.addons.enable_aws_cloudwatch_metrics
  enable_aws_load_balancer_controller   = var.addons.enable_aws_load_balancer_controller
  enable_metrics_server                 = var.addons.enable_metrics_server
  enable_cert_manager                   = var.addons.enable_cert_manager
  enable_external_secrets               = var.addons.enable_external_secrets
  external_secrets                      = var.addons.external_secrets_config
  external_secrets_secrets_manager_arns = var.addons.external_secrets_secrets_manager_arns
  external_secrets_ssm_parameter_arns   = []
  external_secrets_kms_key_arns         = []
  enable_fargate_fluentbit              = var.addons.enable_fargate_fluentbit
  enable_ingress_nginx                  = var.addons.enable_ingress_nginx
  enable_kube_prometheus_stack          = var.addons.enable_kube_prometheus_stack // conflicts with rancher monitoring (prometheus-operator)
  enable_aws_efs_csi_driver             = var.addons.enable_aws_efs_csi_driver


  cert_manager_route53_hosted_zone_arns = var.addons.cert_manager_route53_hosted_zone_arns
  cert_manager                          = var.addons.cert_manager_config
  aws_load_balancer_controller = {
    values = [yamlencode({
      clusterSecretsPermissions = {
        allowAllSecrets = true
      }
      enableServiceMutatorWebhook = false
      vpcId                       = var.vpc_id
      podDisruptionBudget = {
        maxUnavailable = 1
      }
    })]
  }

  enable_aws_for_fluentbit = var.addons.enable_aws_for_fluentbit
  aws_for_fluentbit_cw_log_group = merge(var.addons.aws_for_fluentbit_cw_log_group, {
    name = local.fluentbit_log_group_name
  })

  aws_for_fluentbit = {
    source_policy_documents = data.aws_iam_policy_document.fluentbit_policy[*].json
    //Note: We are setting the retention of the separate log groups to 15 days to account
    //for the process required to delete user data upon request.
    values = [templatefile("${path.module}/templates/fluentbit/aws-for-fluentbit-values.yaml.tpl", {
      cluster_name = local.cluster_name,
      region       = data.aws_region.current.name
      log_group    = local.fluentbit_log_group_name
      exclude_path = join(",", local.exclude_list)
    })]
  }

  enable_external_dns = true
  external_dns = {
    chart_version = var.addons.external_dns_config.chart_version
    create_role   = true
    values = [templatefile("${path.module}/templates/external-dns/values.yaml", {
      txtOwnerId = local.cluster_name
      txtSuffix  = local.cluster_name
      txtPrefix  = ""
      imageTag   = var.addons.external_dns_config.image_tag
    })]
  }
  external_dns_route53_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  enable_karpenter                  = var.addons.enable_karpenter
  karpenter_enable_spot_termination = true
  karpenter = merge(var.addons.karpenter_config, {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    set = [
      {
        name  = "settings.featureGates.driftEnabled"
        value = "true"
      },
      {
        name  = "controller.resources.requests.cpu"
        value = "1"
      },
      {
        name  = "controller.resources.requests.memory"
        value = "4Gi"
      },
      {
        name  = "controller.resources.limits.cpu"
        value = "2"
      },
      {
        name  = "controller.resources.limits.memory"
        value = "4Gi"
      },
      {
        name  = "webhook.enabled"
        value = "false"
      },
      {
        name  = "dnsPolicy"
        value = "Default"
      }
    ]
  })

  karpenter_node = {
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      //TODO - Removed as should not be needed for UCSF implementation
      //OrgwideSecretsReader         = module.orgwide-secrets.orgwide_secrets_policy_arn
    }
    create_iam_role          = true
    iam_role_use_name_prefix = false
    iam_role_name            = "karpenter-${local.cluster_name}"
  }

  eks_addons = {
    coredns = {
      addon_version        = data.aws_eks_addon_version.addons["coredns"].version
      configuration_values = jsonencode({ replicaCount : 3 })
    }
    kube-proxy = {
      addon_version = data.aws_eks_addon_version.addons["kube-proxy"].version
    }
    vpc-cni = {
      addon_version            = data.aws_eks_addon_version.addons["vpc-cni"].version
      service_account_role_arn = aws_iam_role.vpc_cni.arn
      before_compute           = true
      configuration_values = jsonencode({
        # AWS_PROFILE=czi-si  aws eks describe-addon-configuration --addon-name vpc-cni --addon-version v1.15.1-eksbuild.1
        livenessProbeTimeoutSeconds  = 30
        readinessProbeTimeoutSeconds = 30
        resources = {
          limits = {
            cpu    = "0.5"
            memory = "256Mi"
          }
          requests = {
            cpu    = "0.5"
            memory = "256Mi"
          }
        }
      })
    }
    aws-ebs-csi-driver = {
      addon_version            = data.aws_eks_addon_version.addons["aws-ebs-csi-driver"].version
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
  }
}
