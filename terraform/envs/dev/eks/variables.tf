locals {
  owner_roles = [
    # TODO: Not sure if it is required to prevent Unauthorized in Github Actions
    data.terraform_remote_state.access-management.outputs.gh_actions_executor_role.name,
    # TODO: SSO role used when locally applying terraform with an SSO profile; shouldn't be hardcoded tho!
    "AWSReservedSSO_AWSAdministratorAccess_0527ae95c0a72f8c",
    # "gha-seqtoid", // Role used by GH Actions for applying terraform (cypherid-infra & cypherid-web-infra)
    # TODO: Where are these created, and are they necessary? Appear to be deployed via terraform from 'shared-infra'.
    #       For now, we manually created a 'poweruser' IAM role that matches what is in the CZI dev account. (this needs verification)
    "poweruser",
    # "okta-czi-admin",
    # "tfe-si",
  ]

  cluster_name            = var.eks_cluster_name
  iam_cluster_name_prefix = null

  tags            = var.tags # TODO: var.tags is deprecated
  vpc_id          = data.terraform_remote_state.cloud-env.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.cloud-env.outputs.private_subnets
  cluster_version = "1.35"

  node_groups = {
    "arm" = {
      size          = 1
      capacity_type = "ON_DEMAND"
      architecture = {
        ami_type       = "AL2023_ARM_64_STANDARD"
        instance_types = ["t4g.xlarge"]
      }
    },
    # please push teams to use ARM, this is just a backup in case you need it
    "x86" = {
      size          = 1
      capacity_type = "ON_DEMAND"
      architecture = {
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.xlarge"]
      }
    }
  }
  # TODO: Not sure if it is required to prevent Unauthorized in Github Actions
  authorized_github_repos = {
    "IT-Academic-Research-Services" : [
      "seqtoid-graphql-federation-server",
    ]
  }
  addons = {
    enable_guardduty = false # TODO: true
  }
}
