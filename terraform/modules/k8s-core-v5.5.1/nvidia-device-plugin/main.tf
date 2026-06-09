resource "helm_release" "nvidia_daemonset" {
  chart            = "nvidia-device-plugin"
  name             = "nvidia-device-plugin"
  namespace        = "nvidia-device-plugin"
  repository       = "https://nvidia.github.io/k8s-device-plugin"
  version          = var.chart_version
  atomic           = true
  create_namespace = true
  cleanup_on_fail  = true

  values = [
    yamlencode({
      nodeSelector : {
        "nvidia.com/gpu.present" : "true"
      }
      failOnInitError : "false"
    })
  ]
}
