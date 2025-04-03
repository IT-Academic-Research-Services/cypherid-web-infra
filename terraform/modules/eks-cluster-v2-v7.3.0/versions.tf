terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.14"
      configuration_aliases = [aws.us-east-1]
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
  required_version = "~> 1.3"
}