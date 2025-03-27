locals {
  vpc_cidr              = "10.78.0.0/16"
  private_subnet_cidrs  = ["10.78.101.0/24", "10.78.102.0/24", "10.78.103.0/24"]
  public_subnet_cidrs   = ["10.78.1.0/24", "10.78.2.0/24", "10.78.3.0/24"]
  database_subnet_cidrs = ["10.78.201.0/24", "10.78.202.0/24", "10.78.203.0/24"]
  azs                   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  env                   = var.env
  owner                 = var.owner
  project               = var.project
  region                = var.region
  service               = var.component

  zone_id = data.terraform_remote_state.idseq-prod.outputs.idseq_net_zone_id

  k8s_cluster_names = [var.eks_cluster_name]
}
