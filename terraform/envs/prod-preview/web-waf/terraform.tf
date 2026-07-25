# =============================================================================
# prod-preview / web-waf -- the DENY-BY-DEFAULT edge for prod.seqtoid.org (prod account 283694049553).
#
# Unlike the shared regional web-acl module (modules/web-acl-regional-v3.3.1), which is ALLOW-by-default
# (a public WAF that blocks bad actors), this Web ACL is BLOCK-by-default: the ONLY way through is a
# source IP in the UCSF egress allowlist. That is the whitelist lockdown for the pre-prod env. REGIONAL
# scope (for the ALB), so it lives in the ALB's region (us-west-2).
#
# Association: the prod-preview ingress sets alb.ingress.kubernetes.io/wafv2-acl-arn to this ACL's ARN
# (see deploy/argocd/values/seqtoid-web/prod-preview.yaml), so the AWS Load Balancer Controller
# associates it -- this stack just creates the ACL + IP set and outputs the ARN.
# =============================================================================
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.100.0" }
  }
  backend "s3" {
    use_lockfile = true
    bucket       = "tfstate-283694049553"
    key          = "terraform/idseq/envs/prod-preview/components/web-waf.tfstate"
    region       = "us-west-2"
    encrypt      = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = ["283694049553"] # HARD guard: prod account only
  default_tags {
    tags = {
      project   = "seqtoid"
      env       = var.env
      service   = "web-waf"
      managedBy = "terraform"
    }
  }
}

variable "env" {
  type    = string
  default = "prod-preview"
}
variable "region" {
  type    = string
  default = "us-west-2" # REGIONAL WAF must be in the ALB's region
}

# The UCSF egress CIDRs allowed to reach prod.seqtoid.org. FILL THESE with the real UCSF ranges.
# EMPTY = fail-closed: the allow rule matches nothing, so the default BLOCK blocks EVERYONE. That is
# the safe posture -- prod.seqtoid.org is dark until the allowlist is populated.
variable "ucsf_allowlist_cidrs" {
  type        = list(string)
  description = "UCSF egress IPv4 CIDRs allowed to reach prod.seqtoid.org (e.g. 128.218.0.0/16). Empty = everyone blocked."
  default     = [] # REPLACE with UCSF egress IPv4 CIDRs
}
variable "ucsf_allowlist_ipv6_cidrs" {
  type        = list(string)
  description = "UCSF egress IPv6 CIDRs (optional). Empty = no IPv6 allowed."
  default     = [] # REPLACE with UCSF egress IPv6 CIDRs if any
}
