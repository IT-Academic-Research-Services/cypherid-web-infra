locals {
  owner_roles = [
    # TODO: Not sure if it is required to prevent Unauthorized in Github Actions
    data.terraform_remote_state.access-management.outputs.gh_actions_executor_role.name,
    # The APPLY role is the identity CI actually assumes for terraform apply (the executor role
    # above is legacy). The kubernetes/helm/kubectl providers authenticate via `aws eks get-token`
    # as the caller, so without an aws-auth mapping the cluster answers "the server has asked for
    # the client to provide credentials" and every eks/eks-v2 apply fails. Map it. See #687.
    data.terraform_remote_state.access-management.outputs.gh_actions_apply_role.name,
    # TODO: SSO role used when locally applying terraform with an SSO profile; shouldn't be hardcoded tho!
    "AWSReservedSSO_AWSAdministratorAccess_0527ae95c0a72f8c",
    # "gha-seqtoid", // Role used by GH Actions for applying terraform (cypherid-infra & cypherid-web-infra)
    # TODO: Where are these created, and are they necessary? Appear to be deployed via terraform from 'shared-infra'.
    #       For now, we manually created a 'poweruser' IAM role that matches what is in the CZI dev account. (this needs verification)
    "poweruser",
    # "okta-czi-admin",
    # "tfe-si",
  ]

  read_only_roles = [
    # The PLAN role. With `-refresh=false` a plan never touched the cluster, so this was never
    # needed; now that refresh is on, the kubernetes/helm providers must READ k8s state during
    # plan, and they authenticate via `aws eks get-token` as the CALLING identity. Without an
    # aws-auth mapping the cluster answers "the server has asked for the client to provide
    # credentials" and the whole eks-v2 plan fails Unauthorized.
    #
    # It goes in read_only_roles, NOT owner_roles: owner_roles grants system:masters, and the
    # plan role is read-only in AWS by deliberate design (least-privilege). read_only_roles binds
    # it to the eks-readonly ClusterRole -- get/list/watch on everything, write nothing -- so a
    # read-only identity stays read-only inside the cluster too. The cluster-wide read does cover
    # Secrets, which is unavoidable: helm_release stores its state in them, so refreshing a helm
    # release requires reading them.
    data.terraform_remote_state.access-management.outputs.gh_actions_plan_role.name,
  ]

  cluster_name = var.eks_cluster_name

  # Public API endpoint allow-list. During bring-up this defaults to 0.0.0.0/0
  # (see var.eks_public_access_cidrs in terraform.tf) so kubectl/Argo can reach the
  # brand-new cluster from outside the VPC and we cannot lock ourselves out. In-VPC
  # traffic is always allowed: the module hardcodes cluster_endpoint_private_access.
  # HARDENING (deliberate, AFTER the cluster + bastion access path are verified):
  # restrict this to the real office/VPN egress allow-list (CZID #55), or make the
  # endpoint fully private (endpoint_public_access = false + SSM bastion, CZID #322).
  eks_public_access_cidrs = var.eks_public_access_cidrs

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
