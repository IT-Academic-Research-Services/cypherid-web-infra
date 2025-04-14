# variable "users" {
#   description = "A list of unix users to create on the instance. Created user defaults to sudo enabled."
#   type        = list(object({ username : string, sudo_enabled : bool }))
#   default     = []
# }

variable "user_script" {
  type        = string
  description = "A custom script to include as part of the cloudinit process"

  default = <<EOF
#!/bin/bash -e
echo 'custom_user_script: Nothing to do'
EOF
}

variable "user_boothook" {
  type        = string
  description = "A custom boothook to include as part of the cloudinit process"

  default = <<EOF
#!/bin/bash -e
echo 'custom_user_boothook: Nothing to do'
EOF
}

variable "user_cloud_config" {
  type        = string
  description = "A custom cloud-config (yaml) to include as part of the cloud-init process"
  default     = null
}

variable "datadog_api_key" {
  type        = string
  description = "A datadog key to pass to the agent"
  default     = ""
}

variable "base64_encode" {
  type        = string
  description = "Should the cloudinit script be b64 encoded"
  default     = "true"
}

variable "gzip" {
  type        = string
  description = "Should the cloudinit script be gzipped."
  default     = "true"
}

variable "project" {
  type = string
}

variable "owner" {
  type = string
}

variable "env" {
  type = string
}

variable "service" {
  type = string
}

variable "extra_parts" {
  type = list(
    object({ filename : string, content_type : string, content : string })
  )
  default     = []
  description = "Extra cloud-init parts. See https://www.terraform.io/docs/providers/template/d/cloudinit_config.html"
}
