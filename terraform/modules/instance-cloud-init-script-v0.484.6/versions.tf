terraform {
  required_providers {
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3.2"
    }
  }
  required_version = ">= 0.13"
}
