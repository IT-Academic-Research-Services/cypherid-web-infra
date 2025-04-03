output "datadog_agent_hostname" {
  value = "${local.fullname}.${var.namespace}.svc.cluster.local."
}