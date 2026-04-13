module "aws-ecr-repo" {
  source = "git@github.com:chanzuckerberg/cztack//aws-ecr-repo?ref=v0.104.2"

  force_delete    = local.force_delete
  max_image_count = var.max_image_count
  name            = var.ecr_repo_name
  tags            = var.tags
}

resource "terraform_data" "build_push_docker_img" {
  triggers_replace = local.docker_img_src_sha256
  provisioner "local-exec" {
    command = local.docker_build_cmd
  }
}
