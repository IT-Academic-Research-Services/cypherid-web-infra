locals {
  # If and set statements compatible with server-snippets: 
  # set: https://nginx.org/en/docs/http/ngx_http_rewrite_module.html#set
  # if: https://nginx.org/en/docs/http/ngx_http_rewrite_module.html#if
  geo_restriction_server_snippet = <<EOF
uninitialized_variable_warn off;
set $geoip_enabled        true;
set $ip_country_code      $geoip2_country_code;
if ($allowed_country = no) {
  return 451;
}
EOF
  general_server_snippet         = <<EOF
uninitialized_variable_warn off;
EOF

  # map is compatible with http-snippets:
  # map: https://nginx.org/en/docs/http/ngx_http_map_module.html#map
  cluster_geo_restriction_http_snippet = <<EOF
map $geoip2_country_code $allowed_country {
%{for country in var.cluster_geo_restriction.deny}
  ${country} no;
%{endfor}
%{for country in var.cluster_geo_restriction.allow}
  ${country} yes;
%{endfor}
  default ${var.cluster_geo_restriction.default == "allow" ? "yes" : "no"};
}
EOF

  load_geoip_inline_snippets = var.enable_geo_ip_config && var.cluster_geo_restriction != null
}
resource "kubernetes_manifest" "nginx_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "nginx-issuer"
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
    name  = "controller.allowSnippetAnnotations"
    value = "true"
  }

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.podAnnotations.linkerd\\.io/inject"
    value = var.linkerd_annotations.linkerd_inject
    type  = "string"
  }

  set {
    name  = "controller.podAnnotations.config\\.alpha\\.linkerd\\.io/proxy-wait-before-exit-seconds"
    value = var.linkerd_annotations.proxy_wait_before_exit_seconds
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

  set {
    name  = "controller.config.annotations-risk-level"
    value = "Critical"
    type  = "string"
  }

  set {
    name  = "controller.config.strict-validate-path-type"
    value = "false"
    type  = "string"
  }

  set {
    name  = "controller.replicaCount"
    value = var.replicas
  }

  set {
    name  = "controller.config.use-proxy-protocol"
    value = var.enable_proxy_protocol_v2 ? "true" : "false"
    type  = "string"
  }

  set {
    name  = "controller.autoscaling.enabled"
    value = var.enable_autoscaling ? true : false
    type  = "auto"
  }

  set {
    name  = "controller.autoscaling.minReplicas"
    value = var.min_replicas
  }

  set {
    name  = "controller.autoscaling.maxReplicas"
    value = var.max_replicas
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = var.external_traffic_policy
    type  = "string"
  }

  set {
    name  = "controller.config.allow-snippet-annotations"
    value = "true"
  }

  set {
    name  = "controller.config.proxy-body-size"
    value = var.proxy_body_size
    type  = "string"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = var.controller_cpu_request
    type  = "string"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = var.controller_memory_request
    type  = "string"
  }

  dynamic "set" {
    for_each = var.enable_metrics ? ["enabled"] : []
    content {
      name  = "controller.metrics.enabled"
      value = "true"
      type  = "string"
    }
  }

  dynamic "set" {
    for_each = var.enable_prometheus_scraping ? ["enabled"] : []
    content {
      name  = "controller.podAnnotations.prometheus\\.io/port"
      value = "10254"
      type  = "string"
    }
  }

  dynamic "set" {
    for_each = var.enable_prometheus_scraping ? ["enabled"] : []
    content {
      name  = "controller.podAnnotations.prometheus\\.io/scrape"
      value = "true"
      type  = "string"
    }
  }

  dynamic "set" {
    for_each = var.extra_args
    content {
      name  = "controller.extraArgs.${set.key}"
      value = set.value
    }
  }

  dynamic "set" {
    for_each = var.extra_config_settings
    content {
      name  = "controller.config.${set.key}"
      value = set.value
    }
  }

  set {
    name  = "controller.config.allow-snippet-annotations"
    value = "true"
  }

  dynamic "set" {
    for_each = var.enable_geo_ip_config ? [true] : []
    content {
      name  = "controller.config.use-geoip"
      value = "false"
    }
  }

  dynamic "set" {
    for_each = var.enable_geo_ip_config ? [true] : []
    content {
      name  = "controller.config.use-geoip2"
      value = "true"
    }
  }

  dynamic "set" {
    for_each = local.load_geoip_inline_snippets ? [true] : []
    content {
      name  = "controller.config.http-snippet"
      value = local.cluster_geo_restriction_http_snippet
    }
  }

  dynamic "set" {
    # https://stackoverflow.com/a/30550574
    for_each = local.load_geoip_inline_snippets ? [true] : []
    content {
      name  = "controller.config.server-snippet"
      value = local.geo_restriction_server_snippet
    }
  }

  # We need to set this in place if the argus app attempts to set a variable but this doesn't have it
  dynamic "set" {
    for_each = local.load_geoip_inline_snippets ? [] : [true]
    content {
      name  = "controller.config.server-snippet"
      value = local.general_server_snippet
    }
  }

  values = [templatefile("${path.module}/templates/values.yaml", {
    role_arn = module.eks_service_account_nginx_role.iam_role_arn
  })]

}

