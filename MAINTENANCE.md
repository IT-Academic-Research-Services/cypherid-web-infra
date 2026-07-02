# Maintenance register — cypherid-web-infra

**Purpose.** A complete inventory of what in this repo is kept current **automatically**
(SSOT version files + Renovate) versus what a **human must maintain by hand**, with the
exact file path and in-file location of each. If it's in the "human-maintained" table,
nothing will remind you — so this list is how we avoid silently drifting.

> ⚠️ **Renovate is configured (`renovate.json`) but the GitHub app is not enabled
> yet.** Until it is, *everything* below is effectively human-maintained. The
> "Automated" table describes the intended steady state once the app is on.

---

## A. Human-maintained (Renovate / SSOT cannot track these)

| # | Item | Where (path → location in file) | Why it's manual | How to update |
|---|------|--------------------------------|-----------------|---------------|
| A1 | **Vendored modules** (frozen copies of the inaccessible `chanzuckerberg/shared-infra`) | `terraform/modules/{ecs-cluster-v2.2.1, ecs-cluster-v2.4.0, ecs-service-with-alb-v0.421.0, instance-cloud-init-script, instance-cloud-init-script-v0.484.6, machine-images, aws-iam-policy-orgwide-secrets, aws-iam-policy-document-orgwide-secrets}/` (whole dirs) + the `source = "../../../modules/<name>"` lines in their consuming stacks | Local-path `source` → Renovate has no datasource; upstream repo is inaccessible | Manual re-vendor — see [`docs/OPENTOFU.md` → Update a vendored module](docs/OPENTOFU.md#update-a-vendored-module) |
| A2 | **All other in-house modules** | `terraform/modules/*/` (every module is consumed via a local `../` path) | Renovate cannot bump a local-path module source | Edit in place; `make validate` |
| A3 | **Module-local niche providers** `template`, `cloudinit` | `terraform/modules/{ecs-cluster-v2.2.1, ecs-cluster-v2.4.0, ecs-service-with-alb-v0.421.0}/versions.tf` (`required_providers { template }`); `terraform/modules/instance-cloud-init-script*/versions.tf` (`cloudinit`) | Deliberately **not** in `_shared/versions.tf` — `template` has no `darwin_arm64` build, so it must stay module-local. `template` is also deprecated/archived (frozen at 2.2.0) | Leave `template` frozen; `cloudinit` version constraint *is* Renovate-reachable (see B3) |
| A4 | **Backend state config** (the unique state key per stack) | `terraform/envs/<env>/<component>/terraform.tf` → `terraform { backend "s3" { bucket = …, key = "terraform/idseq/envs/<env>/components/<name>.tfstate" } }` | Per-stack literal, unique to each component | Set by hand when adding a component ([OPENTOFU.md §6](docs/OPENTOFU.md#add-a-new-component)) |
| A5 | **Remote-state data sources** (cross-stack dependencies) | `terraform/envs/<env>/<component>/terraform.tf` → `data "terraform_remote_state" "<name>" { config = { bucket, key, region, profile } }` | Per-stack literal pointing at another stack's state | Edit by hand; the `key`/`profile` must match the upstream stack |
| A6 | **Hardcoded AWS identifiers** | account IDs (`tfstate-<id>` backend bucket in `…/terraform.tf`; the `aws_accounts` map in `…/terraform.tf`); S3 bucket-name defaults (`variable "s3_bucket_*"` in `…/terraform.tf`); domains; AMI owner IDs in `terraform/modules/machine-images/` | Real-world identifiers, no upstream to track | Edit by hand; keep in sync with the live AWS accounts |
| A7 | **Provider list membership** (which providers exist, not their versions) | `terraform/_shared/versions.tf` → `required_providers { … }` block | Adding/removing a provider is a design choice | Edit by hand; versions of existing entries are Renovate-managed (B2) |
| A8 | **CI skip & quarantine lists** | `.github/terraform-ci-skip.txt`, `.github/terraform-ci-quarantine.txt` | Hand-curated exclusions (inaccessible deps / known defects) | Edit by hand; remove entries as stacks are fixed |
| A9 | **CI bucketing logic** | `.github/workflows/tofu_ci.yml` (the `find-changed` classification script), `.github/workflows/validate-stack.yml`, `.github/actions/terraform-validate/action.yml` | Bespoke workflow logic | Edit by hand (the `uses:` pins *inside* these files are Renovate-managed — B4) |

> **No committed `.terraform.lock.hcl`** in this repo by design (`renovate.json` sets
> `:maintainLockFilesDisabled`; provider reproducibility comes from the appliance
> provider mirror / CI plugin cache). So provider versions resolve from the `~>`
> constraints in `_shared/versions.tf` — there is no per-stack lockfile to maintain.

---

## B. Automated — SSOT version files + Renovate

| # | Item | Where (path → location in file) | Maintained by |
|---|------|--------------------------------|---------------|
| B1 | **Terraform version** (the single toolchain pin) | `.terraform-version` (whole file); CI reads it via `terraform_version` | Renovate custom manager → `hashicorp/terraform` github-releases (`renovate.json` `customManagers`) |
| B2 | **Provider version constraints** (the single SSOT for all stacks) | `terraform/_shared/versions.tf` → `version = "~> …"` on each `required_providers` entry | Renovate `terraform` manager, grouped into one **"terraform providers"** PR |
| B3 | **Module-local provider constraints** that carry a version | e.g. `terraform/modules/instance-cloud-init-script*/versions.tf` → `cloudinit … version = ">= 2.3.2"` | Renovate `terraform` manager (same group). *Exception:* `template` is source-only/deprecated — nothing to bump (A3) |
| B4 | **GitHub Actions `uses:` pins** | `.github/workflows/*.yml`, `.github/actions/terraform-validate/action.yml` → `uses: …@<ref>` | Renovate `github-actions` manager (grouped) |
| B5 | **Docker base-image digests** | the 2 `Dockerfile*` → `FROM …@sha256:…` | Renovate `dockerfile` manager (grouped; maintains the digests) |
| B6 | **Python deps** | the 2 `requirements*.txt` | Renovate `pip_requirements` manager (grouped) |
| B7 | **External `?ref=` module pins** (public modules, e.g. cztack) | any `source = "github.com/…?ref=v…"` in `terraform/modules/*` or `terraform/envs/*` | Renovate `terraform` manager (same group as B2) |

---

## When you add something, update the register

- **Add a stack** → new backend `key` (A4) and probably new remote-state blocks (A5). No register edit needed (covered by the glob), but follow [OPENTOFU.md §6](docs/OPENTOFU.md#add-a-new-component).
- **Vendor a new module** → add it to A1 and follow the re-vendor procedure; if it pulls a new niche provider, add it to A3.
- **Add a provider** → add the entry to `_shared/versions.tf` (A7); its version becomes Renovate-managed (B2).
- **Add a new tooling/runtime** → if it gets a version file, wire a Renovate manager for it (B1 pattern) so it doesn't become a hidden A-row.
