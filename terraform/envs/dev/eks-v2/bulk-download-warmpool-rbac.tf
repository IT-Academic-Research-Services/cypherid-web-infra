# =============================================================================
# Bulk-download K8s Job launcher -- supporting cluster resources (Forgejo #846 / SMP-1477).
# Pairs with nodepool-seqtoid-bulk-download.tf (the dedicated pool) and the batch stack's
# bulk-download-job IAM role (S3 perms; trust repointed to OIDC in dev/batch/bulk-download.tf).
#
#   1. ServiceAccount  seqtoid-dev/seqtoid-web-bulk-download  -- IRSA -> the S3 job role; the tar
#      Job pods run as this SA.
#   2. RBAC            the app's seqtoid-web SA may create/track/delete Jobs in seqtoid-dev.
#   3. Warm-keeper     a low-priority "balloon" pod holds ONE node warm in the dedicated pool so
#      even a cold-start download begins in seconds; a real tar Job preempts it (guaranteed <30s).
#
# Additive kubectl_manifest; apply with -target on the eks-v2 component.
# =============================================================================

locals {
  bd_ns             = "seqtoid-dev"
  bd_job_sa         = "seqtoid-web-bulk-download"
  bd_app_sa         = "seqtoid-web"
  bd_job_role_arn   = "arn:aws:iam::491013321714:role/seqtoid-web-dev-bulk-download-job"
  bd_pool_taint_key = "seqtoid.io/pool"
  bd_pool           = "bulk-download"
  # Node/Job sizing. The tar job streams S3->tar->S3 (I/O bound, modest memory). The balloon
  # requests the same so the warm node is right-sized for a tar; a real Job preempts and fits.
  bd_req_cpu = "2"
  bd_req_mem = "4Gi"
}

# 1) Job ServiceAccount, IRSA-bound to the S3 job role.
resource "kubectl_manifest" "bulk_download_job_sa" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name        = local.bd_job_sa
      namespace   = local.bd_ns
      annotations = { "eks.amazonaws.com/role-arn" = local.bd_job_role_arn }
    }
  })
}

# 2) RBAC: the app SA (seqtoid-web) manages tar Jobs in its own namespace.
resource "kubectl_manifest" "bulk_download_role" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"
    metadata   = { name = "bulk-download-launcher", namespace = local.bd_ns }
    rules = [
      { apiGroups = ["batch"], resources = ["jobs"], verbs = ["create", "get", "list", "watch", "delete"] },
      { apiGroups = [""], resources = ["pods"], verbs = ["get", "list"] },
      { apiGroups = [""], resources = ["pods/log"], verbs = ["get"] },
    ]
  })
}

resource "kubectl_manifest" "bulk_download_rolebinding" {
  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata   = { name = "bulk-download-launcher", namespace = local.bd_ns }
    roleRef    = { apiGroup = "rbac.authorization.k8s.io", kind = "Role", name = "bulk-download-launcher" }
    subjects   = [{ kind = "ServiceAccount", name = local.bd_app_sa, namespace = local.bd_ns }]
  })
}

# 3a) Low PriorityClass for the warm-keeper so real tar Jobs (default priority 0) preempt it.
resource "kubectl_manifest" "bulk_download_warm_priorityclass" {
  yaml_body = yamlencode({
    apiVersion       = "scheduling.k8s.io/v1"
    kind             = "PriorityClass"
    metadata         = { name = "seqtoid-bulk-download-warm" }
    value            = -10
    globalDefault    = false
    preemptionPolicy = "Never" # the balloon never preempts others; it only gets preempted
    description      = "Warm-keeper for the bulk-download pool; evicted the instant a real tar Job needs the node."
  })
}

# 3b) The balloon Deployment: one pause pod pinned to the dedicated pool, holding a warm node.
resource "kubectl_manifest" "bulk_download_warmpool" {
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata   = { name = "seqtoid-bulk-download-warmpool", namespace = local.bd_ns }
    spec = {
      replicas = 1
      selector = { matchLabels = { app = "seqtoid-bulk-download-warmpool" } }
      template = {
        metadata = { labels = { app = "seqtoid-bulk-download-warmpool" } }
        spec = {
          priorityClassName             = "seqtoid-bulk-download-warm"
          nodeSelector                  = { (local.bd_pool_taint_key) = local.bd_pool }
          tolerations                   = [{ key = local.bd_pool_taint_key, value = local.bd_pool, effect = "NoSchedule" }]
          terminationGracePeriodSeconds = 0
          containers = [{
            name  = "pause"
            image = "registry.k8s.io/pause:3.10"
            resources = {
              requests = { cpu = local.bd_req_cpu, memory = local.bd_req_mem }
              limits   = { cpu = local.bd_req_cpu, memory = local.bd_req_mem }
            }
          }]
        }
      }
    }
  })
}
