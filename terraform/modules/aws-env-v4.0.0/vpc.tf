locals {
  name = substr("${var.project}-${var.env}${var.vpc_name_suffix}", 0, 63)

  tags = {
    managedBy = "terraform"
    Name      = local.name
    project   = var.project
    env       = var.env
    owner     = var.owner
    service   = var.service
  }

  vpc_base_tags = { for k, v in local.tags : k => v if k != "Name" }

  k8s_tags = {
    for cluster in var.k8s_cluster_names : "kubernetes.io/cluster/${cluster}" => "shared"
  }

  k8s_karpenter_tags = {
    for cluster in var.k8s_cluster_names : "karpenter.sh/discovery" => cluster
  }

  private_subnet_tags = merge(local.k8s_tags, local.k8s_karpenter_tags, { "kubernetes.io/role/internal-elb" = 1 })
  public_subnet_tags  = merge(local.k8s_tags, { "kubernetes.io/role/elb" = 1 })

  default_ingress = [
    {
      "action" : "allow",
      "cidr_block" : "0.0.0.0/0",
      "from_port" : 0,
      "protocol" : "-1",
      "rule_no" : 100,
      "to_port" : 0
    },
    {
      "action" : "allow",
      "from_port" : 0,
      "ipv6_cidr_block" : "::/0",
      "protocol" : "-1",
      "rule_no" : 101,
      "to_port" : 0
    }
  ]
}

data "assert_test" "azs_length_check_0" {
  test  = var.skip_az_checks || length(var.azs) == length(var.public_subnet_cidrs)
  throw = "Number of public subnets (${length(var.public_subnet_cidrs)}) has to match the number of availability zones (${length(var.azs)})."
}

data "assert_test" "azs_length_check_1" {
  test  = var.skip_az_checks || length(var.azs) == length(var.private_subnet_cidrs)
  throw = "Number of private subnets (${length(var.private_subnet_cidrs)}) has to match the number of availability zones (${length(var.azs)})."
}

data "assert_test" "azs_length_check_2" {
  test  = var.skip_az_checks || length(var.azs) == length(var.database_subnet_cidrs)
  throw = "Number of database subnets (${length(var.database_subnet_cidrs)}) has to match the number of availability zones (${length(var.azs)})."
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = local.name

  cidr             = var.vpc_cidr
  azs              = var.azs
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  enable_nat_gateway      = true
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = var.create_database_subnet_route_table

  tags = local.vpc_base_tags

  # Add extra tags to subnets, particularly for eks/k8s
  vpc_tags            = local.private_subnet_tags
  private_subnet_tags = local.private_subnet_tags
  public_subnet_tags  = local.public_subnet_tags
  single_nat_gateway  = var.single_nat_gateway

  depends_on = [
    data.assert_test.azs_length_check_0, data.assert_test.azs_length_check_1, data.assert_test.azs_length_check_2
  ]

  default_network_acl_ingress = local.default_ingress
}

resource "aws_default_security_group" "default" {
  vpc_id = module.vpc.vpc_id
  tags = {
    managedBy = "terraform"
    Name      = "${local.name}-default"
    project   = var.project
    env       = var.env
    owner     = var.owner
    service   = var.service
  }
}

locals {
  split   = split("/", var.vpc_cidr)
  address = local.split[0]
  prefix  = local.split[1]

  address_list = split(".", local.address)

  # We have to spell these out because there is no map-over-list function in terraform interpolations.
  # And we have to do the '0 +' thing in order to coerce the values into integers.
  # address_bits = join("", [
  # format("%08b", 0 + local.address_list[0]),
  # format("%08b", 0 + local.address_list[1])]
  # )

  # prefix_8_bits  = join("", [format("%08b", 10)])
  # prefix_12_bits = join("",[format("%08b", 172), format("%08b", 16)])
  # prefix_16_bits = join("", [format("%08b", 192), format("%08b", 168)])

  # vpc_cidr_valid = "${
  #   (substr(local.address_bits, 0, 8) == local.prefix_8_bits && local.prefix >= 8) ||
  #   (substr(local.address_bits, 0, 12) == substr(local.prefix_12_bits, 0, 12) && local.prefix >= 12) ||
  #   (substr(local.address_bits, 0, 16) == local.prefix_16_bits && local.prefix >= 16)
  # }"
}

# # inspired by https://github.com/hashicorp/terraform/issues/2847#issuecomment-343622460
# resource "null_resource" "is-vpc-cidr-valid" {
#   count =  local.vpc_cidr_valid ? 0 : 1

#   "ERROR: Use only a private vpc cidr block (10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16)" = true
# }
