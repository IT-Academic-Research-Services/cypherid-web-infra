# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.

module "k8s-core" {
  source            = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/k8s-core?ref=k8s-core-v5.5.1"
  additional_addons = local.additional_addons
  eks_cluster       = local.eks_cluster
  tags              = local.tags



}
