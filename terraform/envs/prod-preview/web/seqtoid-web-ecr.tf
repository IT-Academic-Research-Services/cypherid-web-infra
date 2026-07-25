# Go-forward seqtoid-web ECR repository for the prod-preview build (prod account 283694049553).
# Mirrors envs/sandbox/web/seqtoid-web-ecr.tf. The prod account has 0 ECR repos today (survey
# 2026-07-25), so this creates the repo the prod-preview chart pulls from
# (283694049553.dkr.ecr.us-west-2.amazonaws.com/seqtoid-web).
resource "aws_ecr_repository" "seqtoid-web-repository" {
  #checkov:skip=CKV_AWS_51:tag immutability gated behind var.ecr_immutable_tags (default MUTABLE) -- mirrors dev/sandbox.
  name                 = "seqtoid-web"
  image_tag_mutability = var.ecr_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  # prod-preview is a rehearsal env, so allow force_delete to clean the repo with the env.
  force_delete = contains(["dev", "sandbox", "prod-preview"], var.env)

  image_scanning_configuration {
    scan_on_push = true
  }

  # AWS-owned key for the focused draft. prod-preview is greenfield, so customer-managed KMS is a
  # clean option later: set var.manage_ecr_kms_cmk=true and add an ecr_hardening.tf (mirror sandbox's)
  # for local.ecr_kms_key_arn, then port the encryption_configuration dynamic block from dev.
}

resource "aws_ecr_lifecycle_policy" "seqtoid-web" {
  repository = aws_ecr_repository.seqtoid-web-repository.name
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
