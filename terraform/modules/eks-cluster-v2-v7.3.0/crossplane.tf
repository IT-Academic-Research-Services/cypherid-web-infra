module "eks_blueprints_crossplane_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.32.1"

  eks_cluster_id    = module.cluster.cluster_name
  enable_crossplane = var.addons.enable_crossplane
  crossplane_helm_config = {
    version = "1.12.1"
    values = [yamlencode({
      args = ["--enable-environment-configs"]
      metrics = {
        enabled = true
      }
      resourcesCrossplane = {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
        requests = {
          cpu    = "100m"
          memory = "1Gi"
        }
      }
      resourcesRBACManager = {
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "100m"
          memory = "512Mi"
        }
      }
    })]
  }

  crossplane_aws_provider = {
    provider_config          = "aws-provider-config"
    provider_aws_version     = "v0.43.1"
    additional_irsa_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  }

  crossplane_kubernetes_provider = {
    enable                      = true
    provider_kubernetes_version = "v0.9.0"
  }

  crossplane_helm_provider = {
    enable                = true
    provider_helm_version = "v0.15.0"
  }

  depends_on = [module.cluster.managed_node_groups, module.eks_blueprints_addons]
}
