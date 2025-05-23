# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.

module "eks-cluster" {
  source                  = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/eks-cluster-v2?ref=eks-cluster-v2-v7.3.0"
  addons                  = local.addons
  authorized_github_repos = local.authorized_github_repos
  cluster_name            = local.cluster_name
  cluster_version         = local.cluster_version
  iam_cluster_name_prefix = local.iam_cluster_name_prefix
  node_groups             = local.node_groups
  owner_roles             = local.owner_roles
  subnet_ids              = local.subnet_ids
  tags                    = local.tags
  vpc_id                  = local.vpc_id


  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}
