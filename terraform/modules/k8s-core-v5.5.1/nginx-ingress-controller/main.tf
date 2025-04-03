resource "kubernetes_manifest" "nginx_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name"      = "nginx-issuer"
    }
    "spec" = {
      "selfSigned" = {}
    }
  }
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.nginx_version
  namespace        = var.namespace
  create_namespace = true
  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.podAnnotations.linkerd\\.io/inject"
    value = "enabled"
    type  = "string"
  }

  set {
    name  = "controller.config.proxy-buffer-size"
    value = "16k"
    type  = "string"
  }

  set {
    name  = "controller.config.client-body-buffer-size"
    value = "32k"
    type  = "string"
  }
}