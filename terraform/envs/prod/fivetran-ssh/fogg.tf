# Auto-generated by fogg. Do not edit
# Make improvements in fogg, so that everyone can benefit.
variable "TFC_RUN_ID" {
  type    = string
  default = "unknown"
}
variable "TFC_WORKSPACE_NAME" {
  type    = string
  default = "unknown"
}
variable "TFC_WORKSPACE_SLUG" {
  type    = string
  default = "unknown"
}
variable "TFC_CONFIGURATION_VERSION_GIT_BRANCH" {
  type    = string
  default = "unknown"
}
variable "TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA" {
  type    = string
  default = "unknown"
}
variable "TFC_CONFIGURATION_VERSION_GIT_TAG" {
  type    = string
  default = "unknown"
}
variable "TFC_PROJECT_NAME" {
  type    = string
  default = "unknown"
}
provider "aws" {

  region  = "us-west-2"
  profile = "idseq-prod"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
  default_tags {
    tags = {
      TFC_RUN_ID                               = coalesce(var.TFC_RUN_ID, "unknown")
      TFC_WORKSPACE_NAME                       = coalesce(var.TFC_WORKSPACE_NAME, "unknown")
      TFC_WORKSPACE_SLUG                       = coalesce(var.TFC_WORKSPACE_SLUG, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_BRANCH     = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_BRANCH, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_TAG        = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_TAG, "unknown")
      TFC_PROJECT_NAME                         = coalesce(var.TFC_PROJECT_NAME, "unknown")
      project                                  = coalesce(var.tags.project, "unknown")
      env                                      = coalesce(var.tags.env, "unknown")
      service                                  = coalesce(var.tags.service, "unknown")
      owner                                    = coalesce(var.tags.owner, "unknown")
      managedBy                                = "terraform"
    }
  }
  allowed_account_ids = ["745463180746"]
}
# Aliased Providers (for doing things in every region).


provider "aws" {
  alias   = "us-west-2"
  region  = "us-west-2"
  profile = "idseq-prod"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
  default_tags {
    tags = {
      TFC_RUN_ID                               = coalesce(var.TFC_RUN_ID, "unknown")
      TFC_WORKSPACE_NAME                       = coalesce(var.TFC_WORKSPACE_NAME, "unknown")
      TFC_WORKSPACE_SLUG                       = coalesce(var.TFC_WORKSPACE_SLUG, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_BRANCH     = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_BRANCH, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_TAG        = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_TAG, "unknown")
      TFC_PROJECT_NAME                         = coalesce(var.TFC_PROJECT_NAME, "unknown")
      project                                  = coalesce(var.tags.project, "unknown")
      env                                      = coalesce(var.tags.env, "unknown")
      service                                  = coalesce(var.tags.service, "unknown")
      owner                                    = coalesce(var.tags.owner, "unknown")
      managedBy                                = "terraform"
    }
  }
  allowed_account_ids = ["745463180746"]
}


provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = "idseq-prod"

  # this is the new way of injecting AWS tags to all AWS resources
  # var.tags should be considered deprecated
  default_tags {
    tags = {
      TFC_RUN_ID                               = coalesce(var.TFC_RUN_ID, "unknown")
      TFC_WORKSPACE_NAME                       = coalesce(var.TFC_WORKSPACE_NAME, "unknown")
      TFC_WORKSPACE_SLUG                       = coalesce(var.TFC_WORKSPACE_SLUG, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_BRANCH     = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_BRANCH, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_COMMIT_SHA, "unknown")
      TFC_CONFIGURATION_VERSION_GIT_TAG        = coalesce(var.TFC_CONFIGURATION_VERSION_GIT_TAG, "unknown")
      TFC_PROJECT_NAME                         = coalesce(var.TFC_PROJECT_NAME, "unknown")
      project                                  = coalesce(var.tags.project, "unknown")
      env                                      = coalesce(var.tags.env, "unknown")
      service                                  = coalesce(var.tags.service, "unknown")
      owner                                    = coalesce(var.tags.owner, "unknown")
      managedBy                                = "terraform"
    }
  }
  allowed_account_ids = ["745463180746"]
}


provider "assert" {}
terraform {
  required_version = "=1.11.3"

  backend "s3" {

    bucket         = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state"
    dynamodb_table = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state-lock"
    key            = "terraform/idseq/envs/prod/components/fivetran-ssh.tfstate"
    encrypt        = true
    region         = "us-west-2"
    profile        = "idseq-prod"


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

      version = "4.34.0"

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

      version = "> 3.30"

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
  default = "fivetran-ssh"
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
    service   = "fivetran-ssh"
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
variable "project_v1" {
  type    = string
  default = "czid"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_aegea_ecs_execute" {
  type    = string
  default = "idseq-prod-aegea-ecs-execute-us-west-2"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_idseq_bench" {
  type    = string
  default = "idseq-bench"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_pipeline_public_assets" {
  type    = string
  default = "idseq-prod-pipeline-public-assets-us-west-2"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_public_references" {
  type    = string
  default = "czid-public-references"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples" {
  type    = string
  default = "idseq-prod-samples-us-west-2"
}
# tflint-ignore: terraform_unused_declarations
variable "s3_bucket_samples_v1" {
  type    = string
  default = "czi-infectious-disease-prod-samples"
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


    bucket = "tfstate-941377154785-test"

    key     = "terraform/idseq/global.tfstate"
    region  = "us-west-2"
    profile = "default"


  }
}
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {


    bucket         = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state"
    dynamodb_table = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state-lock"
    key            = "terraform/idseq/envs/prod/components/db.tfstate"
    region         = "us-west-2"
    profile        = "idseq-prod"


  }
}
data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {


    bucket         = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state"
    dynamodb_table = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state-lock"
    key            = "terraform/idseq/envs/prod/components/ecs.tfstate"
    region         = "us-west-2"
    profile        = "idseq-prod"


  }
}
data "terraform_remote_state" "happy" {
  backend = "s3"
  config = {


    bucket         = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state"
    dynamodb_table = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state-lock"
    key            = "terraform/czid/envs/prod/components/happy.tfstate"
    region         = "us-west-2"
    profile        = "idseq-prod"


  }
}
data "terraform_remote_state" "k8s-core" {
  backend = "s3"
  config = {


    bucket         = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state"
    dynamodb_table = "idseq-prod-s3-tf-state-prod-prod-idseq-infra-prod-state-lock"
    key            = "terraform/czid/envs/prod/components/k8s-core.tfstate"
    region         = "us-west-2"
    profile        = "idseq-prod"


  }
}
# tflint-ignore: terraform_unused_declarations
variable "aws_accounts" {
  type = map(string)
  default = {

    idseq-dev = "941377154785"

    idseq-prod = "745463180746"

  }
}
