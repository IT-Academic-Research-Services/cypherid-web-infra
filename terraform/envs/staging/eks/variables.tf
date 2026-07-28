locals {
  owner_roles = [
    # TODO: Not sure if it is required to prevent Unauthorized in Github Actions
    data.terraform_remote_state.access-management.outputs.gh_actions_executor_role.name,
    # TODO: SSO role used when locally applying terraform with an SSO profile; shouldn't be hardcoded tho!
    "AWSReservedSSO_AWSAdministratorAccess_f655aa408ec10f58",
    # "gha-seqtoid", // Role used by GH Actions for applying terraform (cypherid-infra & cypherid-web-infra)
    # TODO: Where are these created, and are they necessary? Appear to be deployed via terraform from 'shared-infra'.
    #       For now, we manually created a 'poweruser' IAM role that matches what is in the CZI dev account. (this needs verification)
    # "poweruser",
    # "okta-czi-admin",
    # "tfe-si",
  ]

  cluster_name = var.eks_cluster_name

  # CZID #55: restrict the EKS public API endpoint off 0.0.0.0/0.
  # Interim CIDR restriction only — the full private flip (endpoint_public_access
  # = false + SSM bastion) is the separate held P0 #322. In-VPC traffic is
  # unaffected: the module hardcodes cluster_endpoint_private_access = true.
  # ACTION REQUIRED (ops/counsel): replace the placeholder default of
  # var.eks_public_access_cidrs with the real office/VPN egress allow-list.
  eks_public_access_cidrs = var.eks_public_access_cidrs

  tags            = var.tags # TODO: var.tags is deprecated
  vpc_id          = data.terraform_remote_state.cloud-env.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.cloud-env.outputs.private_subnets
  cluster_version = "1.35"

  node_groups = {
    "arm" = {
      #size          = 1
      max_servers   = 20
      capacity_type = "ON_DEMAND"
      architecture = {
        ami_type       = "AL2023_ARM_64_STANDARD"
        instance_types = ["t4g.xlarge"]
      }
    },
    # please push teams to use ARM, this is just a backup in case you need it
    "x86" = {
      #size          = 1
      max_servers   = 10
      capacity_type = "ON_DEMAND"
      architecture = {
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.xlarge"]
      }
    }
  }
  # Retired dead entry (#468/#439): "seqtoid-graphql-federation-server" is a dead
  # repo and "IT-Academic-Research-Services" is the wrong org (ours is
  # thorvath-slower). The real GitHub OIDC deploy-role trust is owned by the
  # access-management stack (D1/CZID-81/26), which federates thorvath-slower and
  # deliberately does NOT add IT-ARS. This cluster grant was never wired to a live
  # repo, so it is emptied rather than repointed — an empty map is a valid
  # map(list(string)) and produces zero trust statements. If the cluster later
  # needs to grant repo access, add the specific thorvath-slower repo(s) here.
  authorized_github_repos = {}
  addons = {
    enable_guardduty = false # TODO: true
  }
}
