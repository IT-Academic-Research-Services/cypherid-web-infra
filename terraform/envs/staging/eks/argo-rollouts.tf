# Argo Rollouts controller for env-staging, brought under Terraform to enable dev's proven
# pingpong (zero-downtime) rollout methodology:
#   * controller.extraArgs += --aws-verify-target-group -- the controller waits for the new
#     pods' ALB target group to be healthy before shifting canary/pingPong weight, so the
#     cutover has no zero-target window (the blueGreen atomic flip did, causing ~30s 503s).
#   * serviceAccount IRSA (rollouts-controller-irsa.tf) so that verify step can call the
#     read-only elbv2 Describe* APIs.
# Mirrors terraform/envs/dev/eks-v2/argo-rollouts.tf. The controller was bootstrapped
# out-of-band on this cluster (helm release argo-rollouts, chart 2.34.3); the import block
# adopts that existing release into state, and the apply aligns it to dev's pinned 2.41.0
# and adds the extraArgs + IRSA. Paired with rolloutStrategy: pingpong in the staging values
# and the pod-readiness-gate-inject namespace label on the seqtoid-web-staging Application.
import {
  to = helm_release.argo_rollouts
  id = "argo-rollouts/argo-rollouts"
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  namespace  = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = "2.41.0"

  values = [yamlencode({
    controller = {
      replicas  = 2
      extraArgs = ["--aws-verify-target-group"]
    }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = module.rollouts_controller_irsa.role_arn
      }
    }
    dashboard   = { enabled = true }
    installCRDs = true
  })]
}
