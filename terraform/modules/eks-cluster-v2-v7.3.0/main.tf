### LIMITATIIONS (al):
### Seamless upgrade from v1 to v2 is not possible. To upgrade, first destroy v1 cluster, then modify fogg.yml to point to the new v2 module, and run create.
### User-data MIME-encoded scripts are not supported.

### To construct a kube config file, follow https://czi.atlassian.net/wiki/spaces/SI/pages/2474147926/Kubernetes+Troubleshooting#Constructing-kube-config

data "aws_eks_addon_version" "addons" {
  for_each           = toset(["vpc-cni", "coredns", "kube-proxy", "aws-ebs-csi-driver", "aws-guardduty-agent"])
  addon_name         = each.value
  kubernetes_version = local.cluster_version
}

resource "aws_placement_group" "az" {
  name            = "${var.tags.project}-${var.tags.env}-${var.tags.service}-pg"
  strategy        = var.placement_group_strategy
  partition_count = length(var.subnet_ids)
}

data "aws_ssm_parameter" "ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${local.cluster_version}/amazon-linux-2/recommended/release_version"
}

data "aws_iam_role" "master_roles" {
  for_each = toset(var.owner_roles)
  name     = each.value
}

data "aws_iam_role" "readonly_roles" {
  for_each = toset(var.read_only_roles)
  name     = each.value
}

resource "kubernetes_cluster_role_v1" "eks-readonly" {
  metadata {
    name = "eks-readonly"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "eks-readonly" {
  metadata {
    name = "eks-readonly"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.eks-readonly.metadata[0].name
  }
  subject {
    kind      = "Group"
    name      = "eks-readonly-group"
    api_group = "rbac.authorization.k8s.io"
  }
}

locals {
  name             = "${var.tags.project}-${var.tags.env}-${var.tags.service}"
  cluster_name     = coalesce(var.cluster_name, local.name)
  eks_cluster_name = module.cluster.cluster_name
  master_roles     = data.aws_iam_role.master_roles
  cluster_version  = coalesce(var.cluster_version, "1.29")

  defaults = {
    cluster_enabled_log_types = ["audit", "authenticator", "api", "controllerManager", "scheduler"]
  }

  # Available versions are listed here - https://github.com/awslabs/amazon-eks-ami/releases
  ami_release_version = nonsensitive(data.aws_ssm_parameter.ami_release_version.value)

  eks_managed_node_groups = {
    for name, group in var.node_groups :
    ("worker-${lower(name)}-${lower(group.architecture.ami_type)}") => {
      name           = "worker-${lower(name)}-${lower(group.architecture.ami_type)}"
      instance_types = group.architecture.instance_types
      capacity_type  = upper(group.capacity_type)
      ami_type       = group.architecture.ami_type

      update_config = {
        max_unavailable_percentage = 25
      }

      lifecycle = {
        create_before_destroy = true
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            encrypted             = true
            volume_size           = var.docker_storage_size
            volume_type           = "gp3"
          }
        }
      }

      min_size     = group.size
      max_size     = max(1, group.size)
      desired_size = group.size

      create_iam_role         = false
      iam_role_arn            = aws_iam_role.node.arn
      create_security_group   = false
      pre_bootstrap_user_data = <<-EOT
  #!/bin/bash
  sed -i '/^KUBELET_EXTRA_ARGS=/a KUBELET_EXTRA_ARGS+=" --anonymous-auth=false"' /etc/eks/bootstrap.sh
  EOT
      # enable_bootstrap_user_data = true
      # bootstrap_extra_args       = module.cloud-init.script
      tags = merge(var.tags, {
        "k8s.io/cluster-autoscaler/${local.cluster_name}"                     = "owned"
        "k8s.io/cluster-autoscaler/enabled"                                   = "true"
        "k8s.io/cluster-autoscaler/node-template/resources/ephemeral-storage" = "${var.docker_storage_size}Gi"
        "cluster_name"                                                        = local.cluster_name
        "index"                                                               = lower(name)
        "architecture"                                                        = group.architecture.ami_type
      })
      subnet_ids = var.subnet_ids

      k8s_labels = {
        "archtype"      = group.architecture.ami_type
        "capacity_type" = group.capacity_type
      }

      taints = group.taints
      labels = group.labels
    }
  }
}

# module "cloud-init" {
#   source = "../instance-cloud-init-script"


#   user_script = ""

#   // terraform-aws-modules/eks/aws does this for us
#   base64_encode = "false"
#   gzip          = "false"

#   users = var.ssh_users

#   project = var.tags.project
#   owner   = var.tags.owner
#   env     = var.tags.env
#   service = var.tags.service

#   datadog_api_key = var.datadog_api_key
# }

resource "aws_kms_key" "secrets" {
  description = "Key used to encrypt Kubernetes secrets for ${local.cluster_name}"
}

data "aws_iam_policy_document" "secrets" {

  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt"
    ]
    resources = [aws_kms_key.secrets.arn]
  }
}

resource "aws_iam_role_policy" "secrets" {
  name   = "${local.name}-secrets"
  role   = aws_iam_role.cluster.name
  policy = data.aws_iam_policy_document.secrets.json
}

# module "orgwide-secrets" {
#   source    = "../aws-iam-policy-orgwide-secrets"
#   role_name = aws_iam_role.node.id
# }

module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  tags = merge(var.tags, local.karpenter_discovery, local.karpenter_discovery_per_cluster)

  cluster_name              = local.cluster_name
  cluster_version           = local.cluster_version
  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  enable_irsa               = true
  cluster_enabled_log_types = coalesce(var.cluster_enabled_log_types, local.defaults["cluster_enabled_log_types"])

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  create_aws_auth_configmap       = false
  manage_aws_auth_configmap       = true

  create_cluster_security_group = false
  cluster_security_group_id     = aws_security_group.cluster.id

  create_node_security_group = false
  node_security_group_id     = aws_security_group.node.id

  create_iam_role = false
  iam_role_arn    = aws_iam_role.cluster.arn

  # if the user configures a Github Action role, add it to the system:masters group
  //TODO - Removed GH actions roles
  aws_auth_roles = concat(var.map_roles, [{
    rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
    username = "system:node:{{EC2PrivateDNSName}}"
    groups = [
      "system:bootstrappers",
      "system:nodes",
    ]
    }], [for role in local.master_roles :
    {
      rolearn  = role.arn
      username = role.name
      groups   = ["system:masters"]
    }
    ], [for role in data.aws_iam_role.readonly_roles :
    {
      rolearn  = role.arn
      username = "eks-readonly"
      groups   = [kubernetes_cluster_role_binding_v1.eks-readonly.subject[0].name]
    }
    ], [{
      // the ArgoCD child role that is assumed by Argo will have access to the cluster by default
      rolearn  = aws_iam_role.child_assume_role.arn
      username = "argocd"
      groups   = ["system:masters"]
  }])
  aws_auth_users    = var.map_users
  aws_auth_accounts = var.map_accounts

  fargate_profiles = merge(var.fargate_profiles, {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
  })

  eks_managed_node_group_defaults = {
    # Our AMIs cause issues with nodes joining the cluster
    #ami_id               = coalesce(var.ami, local.defaults["ami"])
    capacity_type = "ON_DEMAND"
    placement = {
      group_name = aws_placement_group.az.name
    }
    ami_release_version = coalesce(var.ami_release_version, local.ami_release_version)

    enabled_metrics = [
      "GroupDesiredCapacity",
      "GroupInServiceCapacity",
      "GroupPendingCapacity",
      "GroupMinSize",
      "GroupMaxSize",
      "GroupInServiceInstances",
      "GroupPendingInstances",
      "GroupStandbyInstances",
      "GroupStandbyCapacity",
      "GroupTerminatingCapacity",
      "GroupTerminatingInstances",
      "GroupTotalCapacity",
      "GroupTotalInstances",
    ]
  }

  eks_managed_node_groups = local.eks_managed_node_groups

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.secrets.arn
    resources        = ["secrets"]
  }

  cluster_identity_providers = var.identity_provider_configurations
}

resource "aws_iam_role" "ebs_csi" {
  name = "${local.name}-ebs-csi"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = module.cluster.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.cluster.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
            "${replace(module.cluster.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "vpc_cni" {
  name = "${local.name}-vpc-cni"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = module.cluster.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.cluster.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })
}
