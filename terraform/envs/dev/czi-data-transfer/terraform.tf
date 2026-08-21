provider "aws" {

  region  = "us-west-2"
  profile = "idseq-dev"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
  default_tags {
    tags = {
      project   = coalesce(var.tags.project, "unknown")
      env       = coalesce(var.tags.env, "unknown")
      service   = coalesce(var.tags.service, "unknown")
      owner     = coalesce(var.tags.owner, "unknown")
      managedBy = "terraform"
    }
  }
  allowed_account_ids = ["491013321714"]
}

terraform {
  backend "s3" {
    use_lockfile = true # bug-#006: native state locking (Terraform >= 1.10), portable (no DynamoDB)

    bucket = "tfstate-491013321714-test"

    key     = "terraform/idseq/envs/dev/components/czi-data-transfer.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}

variable "env" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "idseq"
}

variable "component" {
  type    = string
  default = "czi-data-transfer"
}

variable "owner" {
  type    = string
  default = "biohub-tech@chanzuckerberg.com"
}

# DEPRECATED: this field is deprecated in favor of AWS provider default tags.
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "idseq"
    env       = "dev"
    service   = "czi-data-transfer"
    owner     = "biohub-tech@chanzuckerberg.com"
    managedBy = "terraform"
  }
}

# Name of the isolated S3 bucket CZI + collaborator (Tiago) write transferred data into.
# Account-suffixed for a globally-unique name -- the same convention as the other dev
# buckets minted in this repo (see idseq-<env>-heatmap-<account_id> in heatmap-optimization).
variable "s3_transfer_destination_bucket" {
  type    = string
  default = "idseq-dev-czi-data-transfer-491013321714"
}
