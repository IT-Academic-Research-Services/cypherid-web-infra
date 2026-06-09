# We install a nodelocaldns cache to speed up and increase DNS resilience
locals {
  nodelocaldns_values = {
    DNSServer       = data.kubernetes_service_v1.dns.spec[0].cluster_ip
    exclude_fargate = "true"
  }
}

data "kubernetes_service_v1" "dns" {
  metadata {
    name      = "kube-dns"
    namespace = "kube-system"
  }
}
resource "helm_release" "nodelocaldns" {
  name       = "nodelocaldns"
  repository = "${path.module}/templates"
  chart      = "nodelocaldns"
  version    = "v0.0.1"
  namespace  = "kube-system"
  values     = [yamlencode(local.nodelocaldns_values)]
}
