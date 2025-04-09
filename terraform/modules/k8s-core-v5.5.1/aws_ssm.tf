# module "aws-ssm" {
#   source  = "../kubernetes-aws-ssm"
#   project = var.tags.project
#   env     = var.tags.env
#   service = "${var.tags.service}-aws-ssm"
#   owner   = var.tags.owner

#   eks_cluster_id          = var.eks_cluster.cluster_id
#   iam_role_path           = local.iam_role_path
#   cluster_oidc_issuer_url = var.eks_cluster.cluster_oidc_issuer_url
#   oidc_provider_arn       = var.eks_cluster.oidc_provider_arn

#   namespace = kubernetes_namespace.k8s_core_namespace.metadata[0].name
# }
