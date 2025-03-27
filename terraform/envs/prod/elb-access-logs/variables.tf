locals {
  bucket_policy = ""
  env           = var.env
  owner         = var.owner
  project       = var.project
  service       = "${var.component}-${var.region}"
}
