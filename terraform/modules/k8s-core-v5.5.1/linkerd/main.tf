
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "gen_linkerd_ca_policy" {
  statement {
    sid = "AllowGenerateLinkerdCA"
    effect = "Allow"
    actions = [
        "ssm:PutParameter",
    ]
    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.eks_cluster.cluster_id}/*"
    ]
  }
  statement {
    sid = "allowdescribe"
    effect = "Allow"
    actions = [
        "ssm:DescribeParameters",
    ]
    resources = ["*"]
  }
}

module "linkerd-service-account" {
  source = "git@github.com:chanzuckerberg/happy//terraform/modules/happy-iam-service-account-eks?ref=v0.128.8"
  aws_iam_policy_json = data.aws_iam_policy_document.gen_linkerd_ca_policy.json
  eks_cluster         = var.eks_cluster
  k8s_namespace       = "kube-system"
    tags                               =  {
    happy_env = var.eks_cluster.cluster_id
    happy_image_tag = "none"
    happy_last_applied = "none"
    happy_region = "none"
    happy_service_name = "none"
    happy_service_type = "none"
    happy_stack_name = "linkerd"
  }
}

// Create the CA key in parameter store if it does not exist yet
// This will not touch the key if it already exists
resource "kubernetes_job" "setup_linkerd_keys" {
  metadata {
    name      = "setup-linkerd-keys"
    namespace = "kube-system"
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          env {
            name  = "cluster_name"
            value = var.eks_cluster.cluster_id
          }
          name  = "setup-linkerd-keys"
          image = "ubuntu:latest"
          command = [
            "bash",
            "-c",
            file("${path.module}/gen_linkerd_ca_key_and_push_to_parameter_store.sh"),
          ]
        }
        host_network                    = true
        automount_service_account_token = true
        service_account_name            = module.linkerd-service-account.service_account_name
        restart_policy                  = "Never"
      }
    }
  }
  timeouts {
    create = "5m"
    update = "5m"
  }
  wait_for_completion = true
}

data "aws_ssm_parameter" "ca_key" {
	name = var.tls_private_key_param_path != ""? var.tls_private_key_param_path : "/${var.eks_cluster.cluster_id}/linkerd/ca.key"
  depends_on = [kubernetes_job.setup_linkerd_keys]
}

data "aws_ssm_parameter" "ca_cert" {
	name = var.tls_private_cert_param_path != ""? var.tls_private_cert_param_path : "/${var.eks_cluster.cluster_id}/linkerd/ca.crt"
    depends_on = [kubernetes_job.setup_linkerd_keys]
}

resource "kubernetes_namespace" "linkerd" {
  metadata {
    name = var.linkerd_namespace
    labels = {
      "config.linkerd.io/admission-webhooks" : "disabled",
      "linkerd.io/is-control-plane" : true,
      "linkerd.io/control-plane-ns" : "linkerd"
      "app.kubernetes.io/managed-by" : "Helm"

    }
    annotations = {
      "linkerd.io/inject" : "disabled"
    }
  }
}

resource "kubernetes_secret" "certificate_secret" {
  type = "kubernetes.io/tls"

  metadata {
    name      = var.linkerd_trust_anchor_secret_name
    namespace = kubernetes_namespace.linkerd.id
  }

  data = {
    "tls.key" : "${data.aws_ssm_parameter.ca_key.value}",
    "tls.crt" : "${data.aws_ssm_parameter.ca_cert.value}"
  }
}


resource "kubernetes_manifest" "linkerd_issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Issuer"
    "metadata" = {
      "name" = var.linkerd_trust_anchor_secret_name
      "namespace" = var.linkerd_namespace
    }
    "spec" = {
      "ca" = {
        "secretName" = var.linkerd_trust_anchor_secret_name
      }
    }
  }
  depends_on = [kubernetes_secret.certificate_secret]
}

resource "kubernetes_manifest" "linkerd-trust-anchor-certificate" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Certificate"
    "metadata" = {
      "name" = var.linkerd_identity_issuer
      "namespace" = var.linkerd_namespace
    }
    "spec" = {
      "commonName" = "identity.linkerd.cluster.local"
      "dnsNames" = [
        "identity.linkerd.cluster.local",
      ]
      "duration" = var.proxy_certificate_duration
      "isCA" = true
      "issuerRef" = {
        "kind" = "Issuer"
        "name" = var.linkerd_trust_anchor_secret_name
      }
      "privateKey" = {
        "algorithm" = var.tls_private_key_algorithm
      }
      "renewBefore" = var.proxy_certificate_renew_before
      "secretName" = var.linkerd_identity_issuer
      "usages" = [
        "cert sign",
        "crl sign",
        "server auth",
        "client auth",
      ]
    }
  }
  depends_on = [kubernetes_manifest.linkerd_issuer]
}

resource "kubernetes_job" "setup_linkerd_webhook_keys" {
  metadata {
    name      = "setup-linkerd-webhook-keys"
    namespace = "kube-system"
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          env {
            name  = "SSM_PREFIX"
            value = "${var.eks_cluster.cluster_id}/linkerd/webhooks"
          }
          name  = "setup-linkerd-keys"
          image = "ubuntu:latest"
          command = [
            "bash",
            "-c",
            file("${path.module}/gen_linkerd_ca_key_and_push_to_parameter_store.sh"),
          ]
        }
        host_network                    = true
        automount_service_account_token = true
        service_account_name            = module.linkerd-service-account.service_account_name
        restart_policy                  = "Never"
      }
    }
  }
  timeouts {
    create = "5m"
    update = "5m"
  }
  wait_for_completion = true
}

data "aws_ssm_parameter" "webhook_ca_key" {
	name = var.webhook_tls_private_key_param_path != ""? var.webhook_tls_private_key_param_path : "/${var.eks_cluster.cluster_id}/linkerd/webhooks/ca.key"
  depends_on = [kubernetes_job.setup_linkerd_webhook_keys]
}

data "aws_ssm_parameter" "webhook_ca_cert" {
	name = var.webhook_tls_private_cert_param_path != ""? var.webhook_tls_private_cert_param_path : "/${var.eks_cluster.cluster_id}/linkerd/webhooks/ca.crt"
    depends_on = [kubernetes_job.setup_linkerd_webhook_keys]
}

resource "kubernetes_secret" "webhook_certificate_secret" {
  metadata {
    name = var.linkerd_webhook_trust_anchor_secret_name
    namespace = kubernetes_namespace.linkerd.id
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.key" : "${data.aws_ssm_parameter.webhook_ca_key.value}",
    "tls.crt" : "${data.aws_ssm_parameter.webhook_ca_cert.value}"
  }
}

resource "kubernetes_manifest" "webhook-issuer" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Issuer"
    "metadata" = {
      "name" = var.linkerd_webhook_trust_anchor_secret_name
      "namespace" = var.linkerd_namespace
    }
    "spec" ={
      "ca" = {
        "secretName": var.linkerd_webhook_trust_anchor_secret_name
      }
    }
  }

  depends_on = [
    kubernetes_secret.webhook_certificate_secret
  ]
}

resource "kubernetes_manifest" "linkerd-sp-validator-certificate" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Certificate"
     "metadata" = {
       "name" = "linkerd-sp-validator"
       "namespace" = var.linkerd_namespace
     }
    "spec" = {
      "commonName" = "linkerd-sp-validator.linkerd.svc"
      "dnsNames" = [
        "linkerd-sp-validator.linkerd.svc"
      ]
      "duration" = var.webhook_certificate_duration
      "isCA" = false
      "issuerRef" = {
        "kind" = "Issuer"
        "name" = var.linkerd_webhook_trust_anchor_secret_name
      }
      "privateKey" = {
        "algorithm" = var.tls_private_key_algorithm
      }
      "renewBefore" = var.webhook_certificate_renew_before
      "secretName" = "linkerd-sp-validator-k8s-tls"
      "usages" = [
        "server auth"
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.linkerd,
    kubernetes_manifest.webhook-issuer
  ]
}

resource "kubernetes_manifest" "linkerd-proxy-injector-certificate" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Certificate"
    "metadata" = {
      "name"      = "linkerd-proxy-injector"
      "namespace" = var.linkerd_namespace
    }
    "spec" = {
      "commonName" = "linkerd-proxy-injector.linkerd.svc"
      "dnsNames" = [
        "linkerd-proxy-injector.linkerd.svc"
      ]
      "duration" = var.webhook_certificate_duration
      "isCA" = false
      "issuerRef" = {
        "kind" = "Issuer"
        "name" = var.linkerd_webhook_trust_anchor_secret_name
      }
      "privateKey" = {
        "algorithm" = var.tls_private_key_algorithm
      }
      "renewBefore" = var.webhook_certificate_renew_before
      "secretName"  = "linkerd-proxy-injector-k8s-tls"
      "usages" = [
        "server auth",
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.linkerd,
    kubernetes_manifest.webhook-issuer
  ]
}

resource "kubernetes_manifest" "linkerd-policy-validator-certificate" {
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind" = "Certificate"
    "metadata" = {
      "name"      = "linkerd-policy-validator"
      "namespace" = var.linkerd_namespace
    }
    "spec" = {
      "commonName" = "linkerd-policy-validator.linkerd.svc"
      "dnsNames" = [
        "linkerd-policy-validator.linkerd.svc"
      ]
      "duration" = var.webhook_certificate_duration
      "isCA" = false
      "issuerRef" = {
        "kind" = "Issuer"
        "name" = var.linkerd_webhook_trust_anchor_secret_name
      }
      "privateKey" = {
        "algorithm" = var.tls_private_key_algorithm
        "encoding": "PKCS8"
      }
      "renewBefore" = var.webhook_certificate_renew_before
      "secretName"  = "linkerd-policy-validator-k8s-tls"
      "usages" = [
        "server auth",
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.linkerd,
    kubernetes_manifest.webhook-issuer
  ]
}

resource "helm_release" "linkerd_crd" {
  name             = "linkerd-crds"
  repository       = "https://helm.linkerd.io/edge"
  chart            = "linkerd-crds"
  namespace        = var.linkerd_namespace
  create_namespace = false
  version          = var.linkerd_crd_chart_version
  depends_on = [
    kubernetes_namespace.linkerd,
    kubernetes_manifest.linkerd-trust-anchor-certificate
  ]
  wait             = true  # do not start control plane upgrade until CRDs are updated
}

resource "helm_release" "linkerd" {
  name             = "linkerd-control-plane"
  repository       = "https://helm.linkerd.io/edge"
  chart            = "linkerd-control-plane"
  namespace        = var.linkerd_namespace
  create_namespace = false
  version          = var.linkerd_control_plane_chart_version

  set {
    name  = "identityTrustAnchorsPEM"
    value = data.aws_ssm_parameter.ca_cert.value
  }
  set {
    name = "proxy.resources.memory.limit"
    value = "1Gi"
  }
  set {
    name = "proxy.resources.memory.request"
    value = "512Mi"
  }
  set {
    name  = "identity.issuer.scheme"
    value = "kubernetes.io/tls"
  }
  set {
    name = "proxyInjector.externalSecret"
    value = "true"
  }
  set {
    name = "proxyInjector.caBundle"
    value = data.aws_ssm_parameter.webhook_ca_cert.value
  }
  set {
    name = "profileValidator.externalSecret"
    value = "true"
  }
  set {
    name = "profileValidator.caBundle"
    value = data.aws_ssm_parameter.webhook_ca_cert.value
  }
  set {
    name = "policyValidator.externalSecret"
    value = "true"
  }
  set {
    name = "policyValidator.caBundle"
    value = data.aws_ssm_parameter.webhook_ca_cert.value
  }
  values = [
    "${file("${path.module}/ha.yml")}"
  ]
  depends_on = [helm_release.linkerd_crd]
}
