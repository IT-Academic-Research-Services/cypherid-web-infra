# =============================================================================
# prod-preview / web -- provider + backend + core vars. LOCKED-DOWN PRE-PROD in the prod account
# (283694049553); NEVER touches customer-facing prod (seqtoid.org).
#
# SCOPE NOTE: the other envs/<env>/web/ dirs are FOGG-GENERATED (aliased providers, remote_state
# data sources, the full s3_bucket_* var set). This is a hand-drafted FOCUSED slice -- just what the
# seqtoid-web ECR + IRSA need. When prod-preview is generated for real, fold these two resources into
# the fogg env (or keep them as additive files, as done for sandbox). versions.tf should be symlinked
# from the shared canonical file like every other stack.
# =============================================================================
terraform {
  required_version = ">= 1.10" # native S3 state locking (use_lockfile)
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.100.0" }
  }
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-283694049553" # existing prod state bucket (survey 2026-07-25); reused
    key          = "terraform/idseq/envs/prod-preview/components/web.tfstate"
    region       = "us-west-2"
    encrypt      = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = ["283694049553"] # HARD guard: this stack may only ever run in the prod account
  default_tags {
    tags = {
      project   = "seqtoid"
      env       = var.env
      service   = "web"
      managedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

variable "env" {
  type    = string
  default = "prod-preview"
}
variable "region" {
  type    = string
  default = "us-west-2"
}
# Foundation resource-name prefix; the prod-preview EKS cluster is <name_prefix>-<env> = seqtoid-prod-preview.
variable "name_prefix" {
  type    = string
  default = "seqtoid"
}
# MUTABLE by default (latest-tag deploy), like dev/sandbox. Flip to immutable once the deploy uses sha tags.
variable "ecr_immutable_tags" {
  type    = bool
  default = false
}
# Greenfield gate for ECR customer-managed KMS. prod-preview IS greenfield, so this MAY be true (then
# add an ecr_hardening.tf mirroring sandbox's for local.ecr_kms_key_arn). Left false for the focused draft.
variable "manage_ecr_kms_cmk" {
  type    = bool
  default = false
}
# Chamber SecureString KMS key ARN for /idseq-prod-preview-web/* params (empty = AWS-managed SSM key).
variable "chamber_kms_key_arn" {
  type    = string
  default = ""
}
