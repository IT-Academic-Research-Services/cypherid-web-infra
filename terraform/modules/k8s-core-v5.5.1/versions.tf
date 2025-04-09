terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # because we use EKS blueprint configuration_values
      version = ">= 4.47.0"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    tls = {
      source = "hashicorp/tls"
    }
    //TODO - Will we be using rancher?
    # rancher2 = {
    #   source  = "rancher/rancher2"
    #   version = "3.1.1"
    # }
  }
  required_version = ">= 1.3"
}

# provider "rancher2" {
#   timeout = "30m"
# }