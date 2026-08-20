provider "aws" {

  region  = "us-west-2"
  profile = "idseq-prod"

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
  allowed_account_ids = ["283694049553"]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "idseq-prod"

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
  allowed_account_ids = ["283694049553"]
}


provider "assert" {}

provider "auth0" {
  # Tenant is decoupled from env: env-prod (the hidden beta deployment) authenticates
  # against the real prod tenant seqtoid-prod, NOT the derived seqtoid-env-prod. Pass
  # -var auth0_domain=seqtoid-prod.us.auth0.com. Empty falls back to the per-env
  # derivation for envs whose tenant name does match seqtoid-<env>.
  domain = var.auth0_domain != "" ? var.auth0_domain : "seqtoid-${var.env}.us.auth0.com"
}
terraform {
  backend "s3" {
    use_lockfile = true # bug-#006: native state locking (Terraform >= 1.10), portable (no DynamoDB)

    bucket = "tfstate-283694049553"

    key     = "terraform/idseq/envs/prod/components/auth0.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "idseq-prod"


  }
}
# tflint-ignore: terraform_unused_declarations
variable "env" {
  type    = string
  default = "prod"
}
# tflint-ignore: terraform_unused_declarations
variable "project" {
  type    = string
  default = "idseq"
}
# tflint-ignore: terraform_unused_declarations
variable "region" {
  type    = string
  default = "us-west-2"
}
# tflint-ignore: terraform_unused_declarations
variable "component" {
  type    = string
  default = "auth0"
}
# tflint-ignore: terraform_unused_declarations
variable "aws_profile" {
  type    = string
  default = "idseq-prod"
}
# tflint-ignore: terraform_unused_declarations
variable "owner" {
  type    = string
  default = "biohub-tech@chanzuckerberg.com"
}
# tflint-ignore: terraform_unused_declarations
# DEPRECATED: this field is deprecated in favor or 
# AWS provider default tags.
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "idseq"
    env       = "prod"
    service   = "auth0"
    owner     = "biohub-tech@chanzuckerberg.com"
    managedBy = "terraform"
  }
}
# tflint-ignore: terraform_unused_declarations
variable "alignment_index_date" {
  type    = string
  default = "2021-01-22"
}
# tflint-ignore: terraform_unused_declarations
variable "base_domain" {
  type    = string
  default = "seqtoid.org"
}
# tflint-ignore: terraform_unused_declarations
variable "build_index_date" {
  type    = string
  default = "2021-01-22"
}
# tflint-ignore: terraform_unused_declarations
variable "eks_cluster_name" {
  type    = string
  default = "czid-prod-eks"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_aegea_ecs_execute" {
  type    = string
  default = "aegea-ecs-execute-prod-283694049553"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_idseq_bench" {
  type    = string
  default = "idseq-bench"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_public_references" {
  type    = string
  default = "seqtoid-public-references"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples" {
  type    = string
  default = "idseq-samples-prod-283694049553"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples_v1" {
  type    = string
  default = "czi-infectious-disease-prod-samples-283694049553"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_secrets" {
  type    = string
  default = "idseq-secrets"
}
data "terraform_remote_state" "route53" {
  backend = "s3"
  config = {


    bucket = "tfstate-283694049553"

    key     = "terraform/idseq/envs/prod/components/route53.tfstate"
    region  = "us-west-2"
    profile = "idseq-prod"


  }
}

# Only read when var.assets_fqdn is empty. env-prod has no web.tfstate (its web layer
# is EKS/Argo, not this repo's web component), so it passes -var assets_fqdn=... and
# this read is skipped. Real prod leaves the var empty and reads assets_fqdn here.
data "terraform_remote_state" "web" {
  count   = var.assets_fqdn != "" ? 0 : 1
  backend = "s3"
  config = {
    bucket  = "tfstate-283694049553"
    key     = "terraform/idseq/envs/prod/components/web.tfstate"
    region  = "us-west-2"
    profile = "idseq-prod"
  }
}

# tflint-ignore: terraform_unused_declarations
variable "aws_accounts" {
  type = map(string)
  default = {

    idseq-dev = "491013321714"

    idseq-prod = "283694049553"

    idseq-staging = "030998640247"

    idseq-support = "941377154785"

  }
}
