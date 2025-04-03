module "nvidia-device-plugin" {
  source        = "./nvidia-device-plugin"
  count         = var.additional_addons.nvidia-device-plugin.enabled ? 1 : 0
  chart_version = var.additional_addons.nvidia-device-plugin.chart_version
}