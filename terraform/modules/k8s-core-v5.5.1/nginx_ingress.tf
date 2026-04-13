locals {
  # linkerd requires the nginx ingress controller to be installed for end to end encryption
  enable_nginx = var.additional_addons.nginx_ingress.enabled || var.additional_addons.linkerd.enabled
}

module "nginx_ingress" {
  count                      = local.enable_nginx ? 1 : 0
  source                     = "./nginx-ingress-controller"
  namespace                  = var.additional_addons.nginx_ingress.namespace
  nginx_version              = var.additional_addons.nginx_ingress.version
  enable_metrics             = var.additional_addons.nginx_ingress.enable_metrics
  enable_prometheus_scraping = var.additional_addons.nginx_ingress.enable_prometheus_scraping
  replicas                   = var.additional_addons.nginx_ingress.replicas
  extra_args                 = var.additional_addons.nginx_ingress.extra_args
  enable_autoscaling         = var.additional_addons.nginx_ingress.enable_autoscaling
  min_replicas               = var.additional_addons.nginx_ingress.min_replicas
  max_replicas               = var.additional_addons.nginx_ingress.max_replicas
  enable_proxy_protocol_v2   = var.additional_addons.nginx_ingress.enable_proxy_protocol_v2
  extra_config_settings      = var.additional_addons.nginx_ingress.extra_config_settings
  enable_geo_ip_config       = var.additional_addons.nginx_ingress.enable_geo_ip_config
  cluster_geo_restriction    = var.additional_addons.nginx_ingress.cluster_geo_restriction
  maxmind_license_key        = var.additional_addons.nginx_ingress.maxmind_license_key
  proxy_body_size            = var.additional_addons.nginx_ingress.proxy_body_size
  eks_cluster                = var.eks_cluster
  tags                       = var.tags
  linkerd_annotations        = var.additional_addons.nginx_ingress.linkerd_annotations
}
