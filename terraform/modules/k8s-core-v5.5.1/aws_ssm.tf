# module "aws-ssm" {
#   source        = "../kubernetes-aws-ssm-k8s-core-v5"
#   eks_cluster   = var.eks_cluster
#   iam_role_path = local.iam_role_path
#   namespace     = kubernetes_namespace.k8s_core_namespace.metadata[0].name
#   tags = merge(var.tags, {
#     service = "${var.tags.service}-aws-ssm"
#   }) # TODO: var.tags is deprecated
# }
