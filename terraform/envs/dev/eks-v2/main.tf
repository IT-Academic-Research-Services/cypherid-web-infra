module "eks-cluster" {
  source                  = "../../../modules/aws-eks-cluster-v0.104.2" # cztack v0.104.2-seqtoid.1
  addons                  = local.addons
  authorized_github_repos = local.authorized_github_repos
  cluster_name            = local.cluster_name
  cluster_version         = local.cluster_version
  node_groups             = local.node_groups
  owner_roles             = local.owner_roles
  read_only_roles         = local.read_only_roles
  subnet_ids              = local.subnet_ids
  tags                    = local.tags
  vpc_id                  = local.vpc_id

  # CZID #55/#322: control-plane endpoint exposure.
  #  - eks_endpoint_private = false (default): public endpoint ON. During bring-up
  #    the allow-list is 0.0.0.0/0 so we can reach the new cluster to bootstrap it;
  #    harden to a scoped office/VPN list (#55) once access is verified.
  #  - eks_endpoint_private = true (#322 flip): public endpoint OFF; the API is
  #    reachable only in-VPC + via the SSM bastion below. The cidrs var is inert
  #    when public access is off.
  # The private endpoint is always on (module hardcodes it) — in-VPC traffic and
  # the end-user app data path are unaffected either way.
  endpoint_public_access       = !var.eks_endpoint_private
  endpoint_public_access_cidrs = local.eks_public_access_cidrs

  providers = {
    aws.us-east-1 = aws.us-east-1
  }
}

# CZID #322: SSM bastion — the access path to the EKS API once it is made
# private. Created only when var.eks_endpoint_private = true, in lockstep with
# the endpoint_public_access flip above, so you never get a private endpoint with
# no way in. Connect:
#   aws ssm start-session --target $(terraform output -raw bastion_instance_id)
module "ssm_bastion" {
  source = "../../../modules/eks-ssm-bastion"
  count  = var.eks_endpoint_private ? 1 : 0

  name                      = local.cluster_name
  vpc_id                    = local.vpc_id
  subnet_id                 = local.subnet_ids[0]
  cluster_security_group_id = module.eks-cluster.cluster_security_group
  tags                      = local.tags
}

output "bastion_instance_id" {
  description = "SSM bastion instance ID (null unless eks_endpoint_private = true). Connect: aws ssm start-session --target <id>"
  value       = var.eks_endpoint_private ? module.ssm_bastion[0].bastion_instance_id : null
}
