module "linkerd" {
  count                               = var.additional_addons.linkerd.enabled ? 1 : 0
  source                              = "./linkerd"
  linkerd_crd_chart_version           = var.additional_addons.linkerd.crd_version
  linkerd_control_plane_chart_version = var.additional_addons.linkerd.control_plane_version
  tls_private_cert_param_path         = var.additional_addons.linkerd.tls_private_cert_param_path
  tls_private_key_param_path          = var.additional_addons.linkerd.tls_private_key_param_path
  eks_cluster                         = var.eks_cluster
}
