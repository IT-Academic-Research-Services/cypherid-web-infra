resource "kubernetes_priority_class" "k8s-cluster-critical" {
  metadata {
    name = "k8s-cluster-critical"
  }

  value = 900000000
}

resource "kubernetes_priority_class" "k8s-node-critical" {
  metadata {
    name = "k8s-node-critical"
  }

  value = 900001000
}

