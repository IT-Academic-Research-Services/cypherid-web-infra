locals {
  base_zone_id = data.terraform_remote_state.idseq-dev.outputs.sandbox_happy_czid_org_zone_id
  cloud-env    = data.terraform_remote_state.cloud-env.outputs
  eks-cluster  = data.terraform_remote_state.eks.outputs
  k8s-core     = data.terraform_remote_state.k8s-core.outputs
  tags         = var.tags

  okta_teams = [
    # By default all CZI has access, change this value to limit which
    # Okta groups can interact with your internal stacks.
    "Everyone"
  ]

  ecr_repos  = local.machine_readable.ecr_repos
  s3_buckets = local.machine_readable.s3_buckets

  additional_secrets = {
    "tfe" : {
      "org" : "happy-czid",
      "url" : "https://si.prod.tfe.czi.technology",
    }
  }
  github_actions_roles = [
    data.terraform_remote_state.eks.outputs.gh_action_role,
  ]
}
