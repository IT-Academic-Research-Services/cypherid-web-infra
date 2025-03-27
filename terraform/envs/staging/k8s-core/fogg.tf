# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.
provider "aws" {

  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = ["732052188396"]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-west-2"
  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = ["732052188396"]
}


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "idseq-dev"

  allowed_account_ids = ["732052188396"]
}


provider "aws" {
  alias   = "czi-si-us-west-2"
  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = ["626314663667"]
}


provider "aws" {
  alias   = "czi-si-us-east-1"
  region  = "us-east-1"
  profile = "idseq-dev"

  allowed_account_ids = ["626314663667"]
}


provider "aws" {
  alias   = "czi-si"
  region  = "us-west-2"
  profile = "idseq-dev"

  allowed_account_ids = ["626314663667"]
}


provider "assert" {}
terraform {
  required_version = "=1.3.6"

  backend "s3" {

    bucket         = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state"
    dynamodb_table = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state-lock"
    key            = "terraform/czid/envs/staging/components/k8s-core.tfstate"
    encrypt        = true
    region         = "us-west-2"
    profile        = "idseq-dev"


  }
  required_providers {

    archive = {
      source = "hashicorp/archive"

      version = "~> 2.0"

    }

    assert = {
      source = "bwoznicki/assert"

      version = "0.0.1"

    }

    aws = {
      source = "hashicorp/aws"

      version = "~> 5.31.0"

    }

    datadog = {
      source = "datadog/datadog"

      version = "3.20.0"

    }

    kubernetes = {
      source = "hashicorp/kubernetes"

      version = "2.23.0"

    }

    local = {
      source = "hashicorp/local"

      version = "~> 2.0"

    }

    null = {
      source = "hashicorp/null"

      version = "3.1.1"

    }

    okta-head = {
      source = "okta/okta"

      version = "~> 3.30"

    }

    opsgenie = {
      source = "opsgenie/opsgenie"

      version = "0.6.14"

    }

    random = {
      source = "hashicorp/random"

      version = "~> 3.4"

    }

    tls = {
      source = "hashicorp/tls"

      version = "~> 3.0"

    }

  }
}
# tflint-ignore: terraform_unused_declarations
variable "env" {
  type    = string
  default = "staging"
}
# tflint-ignore: terraform_unused_declarations
variable "project" {
  type    = string
  default = "czid"
}
# tflint-ignore: terraform_unused_declarations
variable "region" {
  type    = string
  default = "us-west-2"
}
# tflint-ignore: terraform_unused_declarations
variable "component" {
  type    = string
  default = "k8s-core"
}
# tflint-ignore: terraform_unused_declarations
variable "aws_profile" {
  type    = string
  default = "idseq-dev"
}
# tflint-ignore: terraform_unused_declarations
variable "owner" {
  type    = string
  default = "biohub-tech@chanzuckerberg.com"
}
# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
  default = {
    project   = "czid"
    env       = "staging"
    service   = "k8s-core"
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
variable "build_index_date" {
  type    = string
  default = "2021-01-22"
}
# tflint-ignore: terraform_unused_declarations
variable "ie_ops_genie_team" {
  type    = string
  default = "Core Infra Eng"
}
# tflint-ignore: terraform_unused_declarations
variable "project_v1" {
  type    = string
  default = "czid"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_aegea_ecs_execute" {
  type    = string
  default = "aegea-ecs-execute-staging"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_idseq_bench" {
  type    = string
  default = "idseq-bench"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_public_references" {
  type    = string
  default = "czid-public-references"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples" {
  type    = string
  default = "idseq-samples-staging"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples_v1" {
  type    = string
  default = "czi-infectious-disease-staging-samples"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_secrets" {
  type    = string
  default = "idseq-secrets"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_workflows" {
  type    = string
  default = "idseq-workflows"
}
# tflint-ignore: terraform_unused_declarations
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {


    bucket         = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state"
    dynamodb_table = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state-lock"
    key            = "terraform/idseq/global.tfstate"
    region         = "us-west-2"
    profile        = "idseq-dev"


  }
}
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {


    bucket         = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state"
    dynamodb_table = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state-lock"
    key            = "terraform/czid/envs/staging/components/eks.tfstate"
    region         = "us-west-2"
    profile        = "idseq-dev"


  }
}
data "terraform_remote_state" "idseq-dev" {
  backend = "s3"
  config = {


    bucket         = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state"
    dynamodb_table = "idseq-dev-s3-tf-state-dev-dev-idseq-infra-nonprod-state-lock"
    key            = "terraform/idseq/accounts/idseq-dev.tfstate"
    region         = "us-west-2"
    profile        = "idseq-dev"


  }
}
# tflint-ignore: terraform_unused_declarations
variable "aws_accounts" {
  type = map(string)
  default = {

    idseq-dev = "732052188396"

    idseq-prod = "745463180746"

  }
}
