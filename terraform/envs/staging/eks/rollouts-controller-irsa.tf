# IRSA role for the Argo Rollouts controller on env-staging. The controller's
# --aws-verify-target-group step (argo-rollouts.tf) calls read-only elbv2 Describe* APIs to
# confirm the new pods' ALB target group is healthy before shifting canary/pingPong weight;
# this role grants exactly those permissions (mirrors the lb-controller IRSA pattern).
# Ported verbatim from terraform/envs/dev/eks-v2/rollouts-controller-irsa.tf -- same module
# refs work here because staging/eks uses the same aws-eks-cluster module + local.cluster_name
# / local.tags (see lb-controller-irsa.tf).
module "rollouts_controller_irsa" {
  source = "../../../modules/rollouts-controller-irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks-cluster.oidc_provider_arn
  oidc_issuer_url   = module.eks-cluster.cluster_oidc_issuer_url
  tags              = local.tags
}

output "rollouts_controller_role_arn" {
  description = "IAM role ARN for the Argo Rollouts controller -- set on the argo-rollouts controller.serviceAccount.annotations eks.amazonaws.com/role-arn."
  value       = module.rollouts_controller_irsa.role_arn
}
