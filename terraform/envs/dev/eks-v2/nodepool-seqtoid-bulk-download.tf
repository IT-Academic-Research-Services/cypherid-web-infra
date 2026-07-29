# =============================================================================
# Dedicated Karpenter NodePool for bulk-download tar jobs (migrate downloads off aegea/Batch
# onto a warm-EKS K8s Job; Forgejo #846 / SMP-1477, latency follow-up).
#
# Bulk downloads run the s3_tar_writer container as a short K8s Job. They get their OWN pool
# (seqtoid.io/pool=bulk-download), TAINTED so nothing else ever lands here and a big tar can
# never starve the live dev app (which runs on nodepool-seqtoid-web.tf). Karpenter right-sizes
# the node to each Job's resource requests and scales the pool to zero when idle.
#
# ON-DEMAND, not spot: a customer-facing download must not be interrupted mid-tar (a spot
# reclaim = failed download). consolidateAfter keeps a node warm briefly so bursty downloads
# in a session hit a warm node (~seconds to start); a truly-cold first request provisions a
# node (~40-60s). For a hard <30s guarantee even when cold, add a low-priority warm-keeper pod
# (overprovisioning) -- deliberately omitted here to avoid standing cost; toggle if needed.
#
# Reuses the module's `default` EC2NodeClass. Additive kubectl_manifest; apply with -target.
# =============================================================================
resource "kubectl_manifest" "seqtoid_bulk_download_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "seqtoid-bulk-download" }
    spec = {
      # Cost ceiling (NOT a reservation -- Karpenter only launches for Pending pods). Caps how
      # much concurrent tar capacity can spin up so a burst of large downloads can't run away.
      # ~4 concurrent right-sized tar jobs; excess Jobs stay Pending until capacity frees.
      limits = {
        cpu    = "32"
        memory = "128Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        # Keep a node warm ~5m after the last job so back-to-back downloads in a session start
        # in seconds; reclaim when the burst is over. Long enough to finish an image pull + tar.
        consolidateAfter = "5m"
        budgets = [
          { nodes = "10%" },
        ]
      }
      template = {
        metadata = { labels = { "seqtoid.io/pool" = "bulk-download" } }
        spec = {
          # DEDICATED: taint the pool so only pods that explicitly tolerate it (the tar Jobs)
          # ever schedule here. Full isolation from the app + preview pools.
          taints = [
            { key = "seqtoid.io/pool", value = "bulk-download", effect = "NoSchedule" },
          ]
          expireAfter = "168h"
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          terminationGracePeriod = "1h"
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            # ON-DEMAND only: no spot interruption mid-download.
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            # Non-burstable c/m/r. Karpenter picks the cheapest instance that fits the Job's
            # resource requests, so the Job spec is the real right-sizing knob; this range just
            # bounds the family/size. Allow up to 16 vCPU for genuinely large tars.
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["c", "m", "r"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "Gt", values = ["1"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "Lt", values = ["17"] },
            { key = "karpenter.k8s.aws/instance-family", operator = "NotIn",
            values = ["a1", "c1", "cc1", "cc2", "cg1", "cg2", "cr1", "g1", "g2", "hi1", "hs1", "m1", "m2", "m3", "t1"] },
          ]
        }
      }
    }
  })
}
