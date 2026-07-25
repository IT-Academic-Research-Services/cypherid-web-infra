# envs/prod-preview/web (focused draft)

Locked-down pre-prod (`prod-preview`) web-layer resources, in the **prod account** (283694049553).
Never touches customer-facing prod (`seqtoid.org`) -- see
`seqtoid-ssot-infra/env-reconstitute/PROD-PREVIEW-DESIGN.md`.

This is a **hand-drafted focused slice**, not a full fogg-generated env. The other `envs/<env>/web/`
dirs are fogg-generated (aliased providers, remote_state data sources, the full `s3_bucket_*` var set).
Here we draft only what Tom asked for: the go-forward **seqtoid-web ECR** + the **IRSA role**.

## Files
- `terraform.tf` -- provider (hard-guarded to account 283694049553), backend (reuses the existing prod
  state bucket `tfstate-283694049553`, workspace-isolated), and the core vars the ECR/IRSA need.
- `seqtoid-web-ecr.tf` -- ECR repo `seqtoid-web` (the prod account has 0 ECR repos today).
- `eks-irsa.tf` -- IRSA role `seqtoid-web-prod-preview` + trust (seqtoid-prod-preview cluster OIDC) +
  the **complete** chamber/SSM parameter policy. The **app policy is a marked TODO** (greenfield env has
  no ECS-task doc to reuse; it must be authored against prod-preview's own isolated bucket/queue names).

## Remaining before apply
1. Fold into (or generate) the full fogg env for prod-preview, or keep these as additive files.
2. Symlink the canonical `versions.tf`.
3. `seqtoid-prod-preview` EKS cluster must exist first (foundation) -- the IRSA OIDC data source reads it.
4. Author + attach the app IAM policy (S3/SQS/etc.) against prod-preview's isolated resources.
5. Everything is DRAFT/plan -- no apply to the prod account without Tom's explicit go; real prod
   (`seqtoid.org`) is never in scope.
