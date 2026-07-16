# =============================================================================
# Dedicated Karpenter NodePool for seqtoid-web (#486), codified (not kubectl-applied).
#
# The module's DEFAULT NodePool floors instance-cpu > 8 (>=16-vCPU nodes) and only
# consolidates empty nodes after 24h — wasteful for a small dev app and slow to give
# the node back on the weekend cost spin-down. This pool:
#   * labels its nodes `seqtoid.io/pool=web` so the chart's nodeSelector lands here,
#   * allows SMALL amd64 nodes (instance-cpu < 9, e.g. a 2-vCPU c6a.large),
#   * consolidates fast (1m) so a suspend->0 actually frees the node quickly.
# amd64-only because the seqtoid-web image is single-arch amd64 (multi-arch is #482).
#
# Managed as a kubectl_manifest for consistency with the module's own default
# NodePool/EC2NodeClass (also kubectl_manifest). Reuses the module's `default`
# EC2NodeClass (correct subnet/SG/AMI discovery for czid-dev-eks-v2). Applied after
# the cluster exists (depends on the module's karpenter CRDs + nodeclass).
# =============================================================================
resource "kubectl_manifest" "seqtoid_web_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "seqtoid-web" }
    spec = {
      # See platform-overhaul #696. consolidateAfter was 1m: Karpenter churned nodes fast enough to
      # repeatedly evict the SINGLE-REPLICA ArgoCD control plane (repo-server, application-controller,
      # server, redis -- every one of them 1/1), killing in-flight syncs with "connection refused" to a
      # brand-new repo-server pod. Karpenter was dead until 2026-07-14, so nothing was ever consolidated
      # and the cluster was accidentally static; the moment it started working, this surfaced.
      # 15m plus a disruption budget keeps consolidation useful without shredding running work.
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "15m"
        budgets = [
          { nodes = "10%" },
        ]
      }
      template = {
        metadata = { labels = { "seqtoid.io/pool" = "web" } }
        spec = {
          expireAfter = "360h"
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          terminationGracePeriod = "1h"
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "kubernetes.io/os", operator = "In", values = ["linux"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
            # Non-burstable, right-sized dev nodes: c/m/r families, 4-8 vCPU. Burstable t2/t3
            # (excluded by instance-category) were the root cause of the NotReady flapping:
            # under load a 2-vCPU t3 pegged CPU to ~100%, starved the kubelet, and the node
            # dropped its heartbeat. c/m/r at >=4 vCPU gives fixed performance with headroom
            # for the app plus the kubelet reservation (see the module EC2NodeClass). Still
            # "small for dev" (<=8 vCPU) and spot-eligible for cost. See platform-overhaul #699.
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["c", "m", "r"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "Gt", values = ["3"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "Lt", values = ["9"] },
            # Exclude the ancient/instance-store families (mirrors the default pool).
            { key = "karpenter.k8s.aws/instance-family", operator = "NotIn",
            values = ["a1", "c1", "cc1", "cc2", "cg1", "cg2", "cr1", "g1", "g2", "hi1", "hs1", "m1", "m2", "m3", "t1"] },
          ]
        }
      }
    }
  })

  # No broad `depends_on = [module.eks-cluster]`: it would make the whole cluster
  # module a dependency of a -target, dragging unrelated module drift into every
  # scoped apply. The NodePool only needs the Karpenter CRDs to exist first; on a
  # from-empty apply the provider's apply_retry_count (providers.tf) rides out the
  # brief window while the module's karpenter addon registers them.
}
