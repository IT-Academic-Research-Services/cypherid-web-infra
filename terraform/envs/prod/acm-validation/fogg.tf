# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.
provider "aws" {

  version = "~> 3.5.0"
  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = [732052188396]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-east-1"
  version = "~> 3.5.0"
  region  = "us-east-1"
  profile = "idseq-dev"

  allowed_account_ids = [732052188396]
}


provider "aws" {
  alias   = "us-west-2"
  version = "~> 3.5.0"
  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = [732052188396]
}

terraform {
  required_version = "~>0.12.24"

  backend "s3" {

    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/prod/components/acm-validation.tfstate"
    encrypt = true
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
variable "env" {
  type    = string
  default = "prod"
}
variable "project" {
  type    = string
  default = "idseq"
}
variable "region" {
  type    = string
  default = "us-west-2"
}
variable "component" {
  type    = string
  default = "acm-validation"
}
variable "aws_profile" {
  type    = string
  default = "idseq-dev"
}
variable "owner" {
  type    = string
  default = "biohub-tech@chanzuckerberg.com"
}
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "idseq"
    env       = "prod"
    service   = "acm-validation"
    owner     = "biohub-tech@chanzuckerberg.com"
    managedBy = "terraform"
  }
}
variable "alignment_index_date" {
  type    = string
  default = "2020-04-20"
}
variable "build_index_date" {
  type    = string
  default = "2020-04-20"
}
variable "s3_bucket_idseq_bench" {
  type    = string
  default = "idseq-bench"
}
variable "s3_bucket_public_references" {
  type    = string
  default = "idseq-public-references"
}
variable "s3_bucket_secrets" {
  type    = string
  default = "idseq-secrets"
}
variable "s3_bucket_workflows" {
  type    = string
  default = "idseq-workflows"
}
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/global.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
data "terraform_remote_state" "web" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/envs/prod/components/web.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
# remote state for accounts
data "terraform_remote_state" "idseq-dev" {
  backend = "s3"
  config = {


    bucket = "idseq-terraform-infra"

    key     = "terraform/idseq/accounts/idseq-dev.tfstate"
    region  = "us-west-2"
    profile = "idseq-dev"


  }
}
# map of aws_accounts
variable "aws_accounts" {
  type = map(any)
  default = {


    idseq-dev = 732052188396


  }
}
provider "random" {
  version = "~> 2.2"
}
provider "template" {
  version = "~> 2.1"
}
provider "archive" {
  version = "~> 1.3"
}
provider "null" {
  version = "~> 2.1"
}
provider "local" {
  version = "~> 1.4"
}
provider "tls" {
  version = "~> 2.1"
}
