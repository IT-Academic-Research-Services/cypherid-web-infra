// Adds cluster to Rancher
// Relies on RANCHER_ACCESS_KEY, RANCHER_SECRET_KEY and RANCHER_URL environment variables

# This feature conflicts with manually imported clusters; please remove the clusters from Rancher before enabling it. More about the issue:
# https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/manage-clusters/clean-cluster-nodes#:~:text=For%20registered%20clusters%2C%20the%20process,options%20make%20the%20same%20deletions.
resource "rancher2_cluster" "cluster" {
  name        = var.eks_cluster.cluster_id
  description = "${var.eks_cluster.cluster_id} cluster"

  lifecycle {
    create_before_destroy = true
  }
}

resource "kubernetes_namespace_v1" "cattle-system" {
  metadata {
    name = "cattle-system"
  }
}

resource "kubernetes_service_account_v1" "sa" {
  metadata {
    name      = "rancher-provisioner-crd"
    namespace = "kube-system"
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding_v1" "sa" {
  metadata {
    name = "rancher-provisioner-crd"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.sa.metadata[0].name
    namespace = kubernetes_service_account_v1.sa.metadata[0].namespace
  }
}

// Cluster needs to be imported into Rancher by deploying agents. It can be accomplished by running the install job, or by doing this:
// https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/kubernetes-clusters-in-rancher-setup/register-existing-clusters
// Second approach is more reliable, but requires credentials to be set up.

resource "kubernetes_job" "provision_agents" {
  metadata {
    name      = "install-rancher-crds"
    namespace = "kube-system"
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name  = "kubectl"
          image = var.provisioner_image
          command = [
            "kubectl",
            "apply",
            "-f",
            rancher2_cluster.cluster.cluster_registration_token[0].manifest_url,
          ]
        }
        host_network                    = true
        automount_service_account_token = true
        service_account_name            = kubernetes_service_account_v1.sa.metadata[0].name
        restart_policy                  = "Never"
      }
    }
  }
  wait_for_completion = true
  depends_on = [kubernetes_cluster_role_binding_v1.sa, kubernetes_namespace_v1.cattle-system]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [kubernetes_job.provision_agents]

  create_duration = "60s"
}

resource "rancher2_app_v2" "rancher-monitoring" {
  count = var.cluster_monitoring.enabled ? 1 : 0

  cluster_id    = rancher2_cluster.cluster.id
  name          = "rancher-monitoring"
  namespace     = "cattle-monitoring-system"
  repo_name     = "rancher-charts"
  chart_name    = "rancher-monitoring"
  chart_version = var.cluster_monitoring.chart_version
  wait = false
  cleanup_on_fail = true
  force_upgrade = true

  values = yamlencode({
    prometheus-node-exporter = {
      tolerations = [
        {
          operator = "Exists"
        }
      ]
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/os"
                    operator = "In"
                    values   = ["linux"]
                  },
                  {
                    key      = "kubernetes.io/arch"
                    operator = "In"
                    values   = ["amd64", "arm64"]
                  },
                  {
                    key      = "eks.amazonaws.com/compute-type"
                    operator = "NotIn"
                    values   = ["fargate"]
                  }
                ]
              }
            ]
          }
        }
      }
    }
  })

  // Once monitoring is deployed, and updated through rancher, there's no need to revert to a prior version
  lifecycle {
    ignore_changes = all
  }
  depends_on = [ time_sleep.wait_30_seconds ]
}
