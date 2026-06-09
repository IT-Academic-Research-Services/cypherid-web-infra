output "script" {
  value = data.cloudinit_config.script.rendered
}

output "parts" {
  value = local.all_parts
}