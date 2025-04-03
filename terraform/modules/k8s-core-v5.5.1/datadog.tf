module "datadog" {
  count = length(var.additional_addons.datadog.api_key) == 0 ? 0 : 1

  source               = "./datadog"
  eks_cluster_id       = var.eks_cluster.cluster_id
  api_key              = var.additional_addons.datadog.api_key
  agent_tag            = var.additional_addons.datadog.agent_tag
  namespace            = kubernetes_namespace.k8s_core_namespace.metadata[0].name
  priority_class       = kubernetes_priority_class.k8s-cluster-critical.metadata[0].name
  tags                 = var.tags
  ops_genie_owner_team = var.additional_addons.datadog.ops_genie_owner_team
  mute_dd_alerts       = var.additional_addons.datadog.mute
}