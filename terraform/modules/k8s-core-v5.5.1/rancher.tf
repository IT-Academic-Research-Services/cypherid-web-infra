module "rancher" {
  source             = "./rancher"
  count              = var.additional_addons.rancher.enabled ? 1 : 0
  eks_cluster        = var.eks_cluster
  provisioner_image  = var.additional_addons.rancher.provisioner_image
  cluster_monitoring = var.additional_addons.rancher.cluster_monitoring
}
