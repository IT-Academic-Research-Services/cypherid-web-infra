output "vpc_cidrs_dev" {
  value = "10.120.0.0/16"
}

output "vpc_private_subnets_dev" {
  value = ["10.120.1.0/24", "10.120.2.0/24"]
}

output "vpc_public_subnets_dev" {
  value = ["10.120.101.0/24", "10.120.102.0/24"]
}

output "vpc_cidrs_alpha" {
  value = "10.130.0.0/16"
}

output "vpc_private_subnets_alpha" {
  value = ["10.130.1.0/24", "10.130.2.0/24"]
}

output "vpc_public_subnets_alpha" {
  value = ["10.130.101.0/24", "10.130.102.0/24"]
}

output "azs_alpha" {
  value = ["us-west-2a", "us-west-2b"]
}
