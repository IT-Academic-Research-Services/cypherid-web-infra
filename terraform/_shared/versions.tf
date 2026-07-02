# =============================================================================
# CZ ID stack — canonical Terraform version + provider constraints.
#
# THE single source of truth. This file is symlinked into every root stack as
# `versions.tf`. Bump a version here ONCE and every stack moves together — no
# drift, no per-stack edits. (Constitution Principle III: one source of truth.)
#
# Cost of the shared list: a stack resolves every provider named here even if it
# uses only some. That is intentional and free in practice — CI uses a provider
# plugin cache and the appliance ships a local provider mirror, so nothing is
# re-downloaded per stack. Reproducibility > a slightly longer first init.
#
# Licensing gate: all providers below are MPL-2.0 except
# bwoznicki/assert (MIT). No BUSL/SSPL.
#
# Deliberately NOT listed here: niche, module-local providers — currently
# hashicorp/template and hashicorp/cloudinit, declared only in the vendored
# modules that need them (terraform/modules/*/versions.tf). Do NOT promote them
# into this shared list:
#   - template has no darwin_arm64 build (CZID-130). This file is symlinked into
#     EVERY stack, so listing template here would force every stack to resolve it
#     and break local `terraform init` on Apple Silicon repo-wide — instead of only the
#     two stacks (prod/ecs, prod/web) that actually use it. Module-local
#     declaration confines that breakage to its real consumers.
#   - template is also deprecated/archived (only 2.2.0 exists) — nothing to bump.
#
# Maintenance: the constraints in THIS file are Renovate-managed (grouped
# "terraform providers" PR, once CZID-212 enables the app). The vendored modules
# under terraform/modules/ that carry these niche providers are human-maintained
# frozen snapshots — Renovate cannot update a local-path module source. See
# docs/TERRAFORM.md "Vendored modules" for the re-vendor procedure.
# =============================================================================
terraform {
  required_version = ">= 1.10" # >= 1.10 for native S3 state locking (use_lockfile)
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.100.0" }
    archive    = { source = "hashicorp/archive", version = "~> 2.0" }
    assert     = { source = "bwoznicki/assert", version = "0.0.1" }
    auth0      = { source = "auth0/auth0", version = "~> 1.48.0" }
    helm       = { source = "hashicorp/helm", version = "~> 2.17.0" }
    kubectl    = { source = "gavinbunney/kubectl", version = "~> 1.19.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.1.0" }
    local      = { source = "hashicorp/local", version = "~> 2.0" }
    null       = { source = "hashicorp/null", version = "3.1.1" }
    okta-head  = { source = "okta/okta", version = "> 3.30" }
    random     = { source = "hashicorp/random", version = "~> 3.4" }
    tls        = { source = "hashicorp/tls", version = "~> 3.0" }
  }
}
