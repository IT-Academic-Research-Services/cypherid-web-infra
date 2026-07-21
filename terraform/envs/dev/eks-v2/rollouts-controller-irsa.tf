# Argo Rollouts controller IRSA role (platform-overhaul 782) -- via the shared SSOT
# module terraform/modules/rollouts-controller-irsa. The controller is installed
# cluster-wide via GitOps (deploy/argocd/_terraform-owned/argo-rollouts.yaml); it
# assumes this role so its --aws-verify-target-group check can read elbv2 target-group
# health, which is what makes ping-pong (canary + weighted target groups) cutovers
# zero-downtime instead of the ~30s 503 window blueGreen leaves on an ALB.
#
# BOOTSTRAP (post-apply): take rollouts_controller_role_arn below and set it on the
# argo-rollouts Application's controller.serviceAccount.annotations
# "eks.amazonaws.com/role-arn". The role name is deterministic (czid-dev-eks-v2-argo-
# rollouts) so it can also be pre-filled.
module "rollouts_controller_irsa" {
  source = "../../../modules/rollouts-controller-irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks-cluster.oidc_provider_arn
  oidc_issuer_url   = module.eks-cluster.cluster_oidc_issuer_url
  tags              = local.tags
}

output "rollouts_controller_role_arn" {
  description = "IAM role ARN for the Argo Rollouts controller -- set on the argo-rollouts Application's controller.serviceAccount.annotations eks.amazonaws.com/role-arn."
  value       = module.rollouts_controller_irsa.role_arn
}
