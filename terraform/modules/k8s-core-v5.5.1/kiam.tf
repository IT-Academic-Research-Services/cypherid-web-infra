module "kiam" {
  count  = var.additional_addons.kiam ? 1 : 0
  source = "./kiam"

  eks_cluster    = var.eks_cluster
  namespace      = kubernetes_namespace.k8s_core_namespace.metadata[0].name
  priority_class = kubernetes_priority_class.k8s-cluster-critical.metadata[0].name
  tags           = var.tags
}
