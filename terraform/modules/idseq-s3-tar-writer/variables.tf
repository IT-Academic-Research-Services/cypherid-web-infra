variable "aws_account" {
  type     = string
  nullable = false
}

variable "region" {
  type     = string
  nullable = false
}

variable "aws_profile" {
  type     = string
  nullable = false
}

variable "max_image_count" {
  type     = number
  default  = 10
  nullable = false
}

variable "ecr_repo_name" {
  type     = string
  default  = "idseq-s3-tar-writer"
  nullable = false
}

variable "image_tag" {
  type     = string
  default  = "latest"
  nullable = false
}

variable "force_image_rebuild" {
  type     = bool
  default  = false
  nullable = false
}

variable "tags" {
  type = object({
    project : string,
    env : string,
    service : string,
    owner : string,
    managedBy : string
  })
  description = "Tags to apply to ECR repo"
}

locals {
  force_delete = true # default false

  ecr_registry          = trimsuffix(module.aws-ecr-repo.repository_url, "/${module.aws-ecr-repo.repository_name}")
  docker_img_src_sha256 = var.force_image_rebuild == true ? timestamp() : sha256(join("", [for f in fileset(".", "${path.module}/s3_tar_writer/**") : file(f)]))

  docker_build_cmd = <<-EOT
        aws ecr get-login-password --profile ${var.aws_profile} --region ${var.region} | \
            docker login --username AWS --password-stdin ${local.ecr_registry}

        docker buildx build \
            --platform linux/amd64 \
            -t ${module.aws-ecr-repo.repository_url}:${var.image_tag} \
            -f ${path.module}/Dockerfile \
            --push ${path.module}
    EOT
}
