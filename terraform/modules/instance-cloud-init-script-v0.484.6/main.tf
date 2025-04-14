locals {
  default_ssh_users = [
    {
      username     = "czi-admin"
      sudo_enabled = true
    },
  ]
  // HACK HACK(el): We do this horrible hack for sudo/non-sudo because terraform
  //     coerces both branches in a ternary to have the same type.
  //     Therefore something like a == "" ? "some string" : false
  //     gets yamlencoded as "false" (!!string) instead of false (!!bool)
  //TODO - Removed users for now.
  users         = {} //concat(local.default_ssh_users, var.users)
  users_sudo    = [for user in local.users : user if tobool(lookup(user, "sudo_enabled", true)) == true]
  users_no_sudo = [for user in local.users : user if tobool(lookup(user, "sudo_enabled", true)) == false]
  cloudinit_users_sudo = [for user in local.users_sudo :
    {
      name : user["username"]
      sudo : "ALL=(ALL) NOPASSWD:ALL"
      shell : "/bin/bash"
      lock_passwd : true
    }
  ]
  cloudinit_users_no_sudo = [for user in local.users_no_sudo :
    {
      name : user["username"]
      sudo : false
      shell : "/bin/bash"
      lock_passwd : true
    }
  ]
  cloudinit_all_users = {
    users : concat(
      ["default"],
      local.cloudinit_users_no_sudo,
    local.cloudinit_users_sudo)
  }

  // Authorize users to ssh as themselves
  authorize_ssh = {
    write_files : [for user in local.users :
      {
        content : user["username"],
        // line-delimited file of authorized principals for this linux user
        // we currently only authorize principals to ssh as themselves
        path : "/etc/ssh/auth_principals/${user["username"]}"
        permissions : "0444",
        owner : "root:root",
      }
    ]
  }

  user_cloud_config = {
    filename : "user_cloud_config.cfg"
    content_type : "text/cloud-config"
    content : var.user_cloud_config
  }

  extra_parts = var.user_cloud_config != null ? [local.user_cloud_config] : []

  enable_datadog = yamlencode({
    write_files : [
      {
        content : yamlencode(
          {
            api_key = var.datadog_api_key
            site : "datadoghq.com"
            tags : [
              "project:${var.project}",
              "env:${var.env}",
              "owner:${var.owner}",
              "service:${var.service}",
            ]
            collect_ec2_tags : true,
            cloud_provider_metadata : ["aws"]
          }
        )
        path : "/etc/datadog-agent/datadog.yaml"
        permissions : "0644"
        owner : "root:root"
        append : true
      }
    ]
    // write updated api_key to /etc/datadog-agent/auth_token
    runcmd : [
      ["systemctl", "restart", "--no-block", "datadog-agent"]
    ]
  })
  // if we don't have a datadog key, disable the agent
  disable_datadog = yamlencode({
    runcmd = [
      ["systemctl", "stop", "--no-block", "datadog-agent"],
      ["systemctl", "disable", "--no-block", "datadog-agent"],
    ]
  })

  parts = [
    {
      filename     = "user_data.sh"
      content_type = "text/x-shellscript"
      content      = var.user_script
    },
    {
      filename     = "user_boothook.sh"
      content_type = "text/cloud-boothook"
      content      = var.user_boothook
    },
    {
      filename     = "setup_users.cfg"
      content_type = "text/cloud-config"
      content      = yamlencode(local.cloudinit_all_users)
    },
    {
      filename     = "authorize_ssh.cfg"
      content_type = "text/cloud-config"
      content      = yamlencode(local.authorize_ssh)

    },
    {
      filename     = "configure_datadog.cfg"
      content_type = "text/cloud-config"
      content      = var.datadog_api_key == "" ? local.disable_datadog : local.enable_datadog
    }
  ]

  all_parts = concat(local.parts, local.extra_parts, var.extra_parts)
}

data "cloudinit_config" "script" {
  gzip          = var.gzip
  base64_encode = var.base64_encode

  dynamic "part" {
    for_each = local.all_parts
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
      merge_type   = "list(append)+dict(no_replace,recurse_list)"
    }
  }
}
