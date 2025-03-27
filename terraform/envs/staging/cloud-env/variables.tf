locals {
  vpc_cidr              = "10.131.0.0/16"
  private_subnet_cidrs  = ["10.131.101.0/24", "10.131.102.0/24"]
  public_subnet_cidrs   = ["10.131.1.0/24", "10.131.2.0/24"]
  database_subnet_cidrs = ["10.131.201.0/24", "10.131.202.0/24"]
  azs                   = ["us-west-2a", "us-west-2b"]
  env                   = var.env
  owner                 = var.owner
  project               = var.project
  region                = var.region
  service               = var.component

  zone_id            = data.terraform_remote_state.idseq-dev.outputs.staging_idseq_net_zone_id
  single_nat_gateway = true

  k8s_cluster_names = [var.eks_cluster_name]
}
