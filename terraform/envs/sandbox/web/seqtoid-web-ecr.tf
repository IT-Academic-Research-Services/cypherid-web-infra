# =============================================================================
# Go-forward `seqtoid-web` ECR repository for the sandbox account (941377154785).
# Mirrors envs/dev/web/seqtoid-web-ecr.tf. PURELY ADDITIVE -- a NEW repo alongside the
# legacy idseq-web (aws_ecr_repository.web-repository in main.tf); does not touch it.
# Needed so a seqtoid-web image can be pushed into sandbox ECR before the app deploys
# (the sandbox.yaml chart values pull 941377154785.dkr.ecr.../seqtoid-web).
# Reuses the env's existing vars: var.ecr_immutable_tags, var.manage_ecr_kms_cmk, var.env.
# =============================================================================

resource "aws_ecr_repository" "seqtoid-web-repository" {
  #checkov:skip=CKV_AWS_51:tag immutability is gated behind var.ecr_immutable_tags (default MUTABLE) -- mirrors dev/idseq-web; re-enable once the deploy uses immutable sha tags.
  name                 = "seqtoid-web"
  image_tag_mutability = var.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  # sandbox is in the force_delete allowlist (rehearsal env), so the repo can be torn
  # down cleanly with the rest of the env.
  force_delete = contains(["dev", "sandbox"], var.env)

  image_scanning_configuration {
    scan_on_push = true
  }

  # Customer-managed KMS gated on var.manage_ecr_kms_cmk (default false -> AWS-owned key, matching
  # idseq-web on sandbox). Reuses this env's local.ecr_kms_key_arn (ecr_hardening.tf), same as the
  # legacy web-repository in main.tf -- so seqtoid-web and idseq-web encrypt identically.
  dynamic "encryption_configuration" {
    for_each = var.manage_ecr_kms_cmk ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = local.ecr_kms_key_arn
    }
  }
}

resource "aws_ecr_lifecycle_policy" "seqtoid-web" {
  repository = aws_ecr_repository.seqtoid-web-repository.name

  # Sane default for a rehearsal repo: reap untagged images so it does not grow unbounded.
  # (Port dev's exact policy here if sandbox should match dev's retention precisely.)
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      }
    ]
  })
}
