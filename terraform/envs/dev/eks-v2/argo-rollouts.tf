# Argo Rollouts controller as a first-class Terraform helm_release (platform-overhaul
# 783). It was originally bootstrapped by a bare `helm install` (rev 1, 2026-07-05), so
# nothing in IaC owned it and its values could not be changed through gitops/terraform.
# This adopts the existing release into Terraform state (import block) so its values --
# including the ping-pong zero-downtime knobs -- are managed here.
#
# The import block runs on the next plan/apply (Terraform >= 1.5) and is a no-op once the
# release is in state, so it is safe to leave. The values below MUST match the original
# `helm install` (controller.replicas=2, dashboard.enabled=true, installCRDs=true) so the
# adopt is a minimal diff; the only intended change is the two additions:
#   * controller.extraArgs += --aws-verify-target-group  -- the controller verifies the
#     new color's ALB target group is healthy before scaling down the old color (the
#     belt-and-suspenders half of the 782 pingpong fix).
#   * serviceAccount.annotations eks.amazonaws.com/role-arn  -- IRSA so that verify step
#     can call the read-only elbv2 Describe* APIs (role from rollouts-controller-irsa).
# Applying this rolls the controller pods once (adds the arg); harmless when no rollout is
# mid-flight.
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
