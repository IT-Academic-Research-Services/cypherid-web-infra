locals {
  # linkerd requires the nginx ingress controller to be installed for end to end encryption
  enable_nginx = var.additional_addons.nginx_ingress.enabled || var.additional_addons.linkerd.enabled
}

module "nginx_ingress" {
  count         = local.enable_nginx ? 1 : 0
  source        = "./nginx-ingress-controller"
  namespace     = var.additional_addons.nginx_ingress.namespace
  nginx_version = var.additional_addons.nginx_ingress.version
}
