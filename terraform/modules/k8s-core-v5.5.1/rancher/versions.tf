terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.1.1"
    }
  }
  required_version = ">= 1.3"
}