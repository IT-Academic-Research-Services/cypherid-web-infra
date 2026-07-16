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

# Let eks-blueprints-addons module handle Karpenter node IAM role automatically

# Stage 1: Karpenter controller only (runs first to provide compute)
module "karpenter_controller" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.22.0"

  tags = var.tags

  cluster_name      = module.cluster.cluster_name
  cluster_endpoint  = module.cluster.cluster_endpoint
  oidc_provider_arn = module.cluster.oidc_provider_arn
  cluster_version   = module.cluster.cluster_version

  # Only Karpenter controller in this stage
  enable_karpenter                  = var.addons.enable_karpenter
  karpenter_enable_spot_termination = true
  karpenter = merge(var.addons.karpenter_config, {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    set = [
      {
        name  = "settings.featureGates.spotToSpotConsolidation"
        value = "true"
      },
      {
        name  = "settings.featureGates.driftEnabled"
        value = "true"
      },
      {
        # Auto-replace nodes that go unhealthy (Ready=Unknown/False past Karpenter's
        # toleration) instead of letting them accumulate. Without this, 9 spot nodes sat
        # NotReady for ~17h holding ~114 subnet IPs and starved new nodes (dev eks-v2
        # incident 2026-07-15). Karpenter drains + terminates + replaces them.
        name  = "settings.featureGates.nodeRepair"
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
      },
    ]
  })

  karpenter_node = {
    create_iam_role       = false
    iam_role_name         = aws_iam_role.karpenter_node.name
    iam_role_arn          = aws_iam_role.karpenter_node.arn
    instance_profile_name = aws_iam_instance_profile.karpenter_node.name
  }

  depends_on = [
    time_sleep.fargate_ready
  ]
}

resource "time_sleep" "karpenter_ready" {
  depends_on = [
    module.karpenter_controller,
    kubectl_manifest.karpenter_nodepool,
    kubectl_manifest.karpenter_node_class
  ]
  create_duration = "30s"
}

# Stage 2: EKS addons only (runs after Karpenter controller to enable compute-dependent addons)
module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.22.0"

  tags = var.tags

  cluster_name      = module.cluster.cluster_name
  cluster_endpoint  = module.cluster.cluster_endpoint
  oidc_provider_arn = module.cluster.oidc_provider_arn
  cluster_version   = module.cluster.cluster_version

  # Only EKS addons in this stage
  # Addon versions PINNED (platform-overhaul #690). Previously most_recent=true, which resolved the
  # version at APPLY time -> a perpetual "addon_version -> (known after apply)" diff on every plan AND
  # a silent-bump risk (any apply could upgrade coredns/vpc-cni/etc. on the live cluster). Pinned to
  # the versions live on dev 2026-07-15; bump deliberately via a version-bump PR.
  eks_addons = {
    eks-pod-identity-agent = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = "v1.3.10-eksbuild.3"
    }

    coredns = {
      addon_version     = "v1.14.3-eksbuild.3"
      resolve_conflicts = "OVERWRITE"
    }

    kube-proxy = {
      addon_version     = "v1.35.3-eksbuild.13"
      resolve_conflicts = "OVERWRITE"
    }

    vpc-cni = {
      addon_version            = "v1.22.3-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.vpc_cni.arn
      # This cluster's aws-node roll on a vpc-cni addon update can exceed the AWS provider's default
      # 20m wait, so `apply` reports "timeout waiting for state Successful (InProgress)" even though
      # AWS finishes the update. Give it 40m so a real apply does not flap on a success. (#690/#699)
      timeouts = { update = "40m" }
      configuration_values = jsonencode({
        # AWS_PROFILE=czi-si  aws eks describe-addon-configuration --addon-name vpc-cni --addon-version v1.15.1-eksbuild.1
        # CNI IP tuning (dev eks-v2 node-death incident 2026-07-15). ROOT CAUSE: the CNI attaches a
        # 3rd ENI to small t3 spot nodes -- driven by the default WARM_ENI_TARGET=1 keeping a SPARE
        # ENI the node does not need -- and a 3-ENI config breaks the node dataplane, so kubelet +
        # SSM lose connectivity ~10min after boot while the instance stays "running". Nodes that
        # stay <=2 ENIs survive indefinitely (verified vs an 18h survivor); the spot nodes only run
        # ~5-6 IP-pods so <=2 ENIs is plenty. Fix: WARM_ENI_TARGET=0 (no spare ENI) + small warm IP
        # pool. NON-prefix on purpose: prefix delegation needs contiguous /28 blocks the churned /24
        # subnets do not have (it starved pods when tried live). Applied live to the managed addon
        # 2026-07-15; this keeps TF in sync. The bulletproof endgame -- a dedicated 100.64.0.0/10
        # secondary CIDR + prefix delegation so nodes never need a 2nd ENI at any scale -- is tracked
        # in platform-overhaul #699.
        env = {
          ENABLE_PREFIX_DELEGATION = "false" # explicit so TF matches the live addon (no perpetual diff)
          WARM_ENI_TARGET          = "0"
          WARM_IP_TARGET           = "4"
          MINIMUM_IP_TARGET        = "8"
        }
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
        podAnnotations = {
          "prometheus.io/port"   = "61678",
          "prometheus.io/scrape" = "true"
        }
      })
    }

    aws-ebs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = "v1.62.0-eksbuild.1"
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }

    aws-mountpoint-s3-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = "v2.7.0-eksbuild.1"
      service_account_role_arn = aws_iam_role.s3_csi.arn
    }
  }

  depends_on = [
    time_sleep.karpenter_ready
  ]
}

# Stage 3: All other addons (runs after Karpenter nodepool/ec2nodeclass provide compute)
module "other_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.22.0"

  tags              = var.tags
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

  enable_external_dns = var.addons.enable_external_dns
  external_dns = {
    chart_version = var.addons.external_dns_config.chart_version
    create_role   = true
    values = [templatefile("${path.module}/templates/external-dns/values.yaml", {
      txtOwnerId = local.cluster_name
      txtSuffix  = local.cluster_name
      txtPrefix  = ""
      imageTag   = var.addons.external_dns_config.image_tag
      policy     = var.addons.external_dns_config.policy
      sources    = var.addons.external_dns_config.sources
    })]
  }
  external_dns_route53_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  # This stage runs after karpenter nodepool provides compute
  depends_on = [
    module.eks_addons
  ]
}