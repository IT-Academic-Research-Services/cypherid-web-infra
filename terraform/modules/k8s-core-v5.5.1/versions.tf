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

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
  required_version = ">= 1.3"
}
