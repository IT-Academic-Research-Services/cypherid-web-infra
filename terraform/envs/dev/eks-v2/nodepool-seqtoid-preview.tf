# =============================================================================
# Dedicated Karpenter NodePool for per-PR preview sandboxes (#607c/#617).
#
# Previews run on their OWN pool (seqtoid.io/pool=preview), SEPARATE from the app pool
# (nodepool-seqtoid-web.tf), for two reasons:
#   * COST CAP: this pool has `limits` (total cpu/memory). Karpenter refuses to launch
#     more nodes once the cap is hit, so unbounded preview fan-out (many open labelled
#     PRs) can never run away with spend -- excess sandbox pods just stay Pending. The
#     app pool has no such cap and must not be squeezed by previews.
#   * ISOLATION: preview pods never share a node with the live dev app.
#
# Small amd64 spot nodes (previews are ephemeral + interruption-tolerant); fast
# consolidation; a short node expireAfter so recycled preview capacity is reclaimed.
# Reuses the module's `default` EC2NodeClass (same subnet/SG/AMI discovery as the web
# pool). Additive kubectl_manifest; apply with -target.
# =============================================================================
resource "kubectl_manifest" "seqtoid_preview_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "seqtoid-preview" }
    spec = {
      # Hard ceiling on total preview capacity: the runaway-cost backstop for fan-out.
      # Karpenter refuses to launch past it and excess sandbox pods stay Pending.
      #
      # SIZED FROM MEASURED USAGE. The previous cap (cpu 16) was sized for "~8-10 concurrent
      # sandboxes (each ~700m cpu / ~2.5Gi)". A sandbox actually costs ~7.8Gi -- web 1280Mi +
      # resque 1536Mi + scheduler 1Gi + pipeline-monitor 2Gi + result-monitor 2Gi -- because
      # every Rails worker loads the whole app. The estimate was ~3x low, so a pool believed to
      # hold 8-10 sandboxes held TWO, and the third dev's sandbox sat Pending forever with
      # "all available instance types exceed limits for nodepool".
      #
      # It also bound on the wrong axis. Permitted instances are c/m/r at 4-8 vCPU, and karpenter
      # picks the cheapest -- almost always c-family, at 1 vCPU : 2 GiB. So cpu 16 could only ever
      # reach ~32Gi of nodes: the 64Gi memory limit was unreachable and CPU capped the pool at
      # half its stated memory. Keep the two axes in the ratio the instances actually come in
      # (32 vCPU <-> 64 GiB for c-family) so neither limit is decoration.
      #
      # TARGET: 3 concurrent sandboxes, because there are 3 devs and sandboxes are per-PR --
      # concurrency equals team size, not PR count. 3 x 7.8Gi = ~23.4Gi, plus daemonsets and
      # bin-packing waste, on ~6.5Gi-allocatable nodes = ~5-6 nodes. 32 vCPU allows 8, leaving
      # room for a 4th sandbox and for pods that cannot pack perfectly.
      #
      # This is a CEILING, NOT A RESERVATION. Karpenter only launches nodes for pods that are
      # actually Pending, so raising the cap costs nothing until a 3rd sandbox exists; it only
      # stops being a wall when real demand arrives. Nodes are spot and expire after 168h.
      #
      # The real lever is per-sandbox cost, not this number: the resque monitors want ~1.6Gi each
      # for what is a polling loop, which smells like a leak or an unbounded batch rather than a
      # genuine working set. Fix that and a sandbox drops toward ~3Gi, 3 of them fit inside the
      # OLD cap, and this number can come back down.
      limits = {
        cpu    = "32"
        memory = "64Gi"
      }
      # consolidateAfter was 1m, which is aggressive enough to be actively harmful: Karpenter kept
      # reclaiming preview nodes out from under pods that were still PULLING their image (the Rails
      # image is large), so the pull restarted on a fresh node -- forever. It also evicted the sandbox
      # provision/migrate Jobs mid-run. 15m lets a node finish what it started.
      #
      # budgets caps how much may be disrupted at once, so one consolidation sweep can never take out
      # the whole pool simultaneously. See platform-overhaul #696.
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "15m"
        budgets = [
          { nodes = "10%" },
        ]
      }
      template = {
        metadata = { labels = { "seqtoid.io/pool" = "preview" } }
        spec = {
          # Shorter than the app pool (360h): preview nodes are ephemeral, recycle them.
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
            # Spot-first: previews tolerate interruption (a killed sandbox pod just
            # reschedules; no live user traffic depends on it).
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
            # Non-burstable, 4-8 vCPU (mirrors the web pool). Burstable t2/t3 (excluded by
            # instance-category) saturated CPU under load and starved the kubelet into
            # NotReady flapping. c/m/r at >=4 vCPU gives fixed performance with headroom.
            # See platform-overhaul #699.
            { key = "karpenter.k8s.aws/instance-category", operator = "In", values = ["c", "m", "r"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "Gt", values = ["3"] },
            { key = "karpenter.k8s.aws/instance-cpu", operator = "Lt", values = ["9"] },
            { key = "karpenter.k8s.aws/instance-family", operator = "NotIn",
            values = ["a1", "c1", "cc1", "cc2", "cg1", "cg2", "cr1", "g1", "g2", "hi1", "hs1", "m1", "m2", "m3", "t1"] },
          ]
        }
      }
    }
  })
}
