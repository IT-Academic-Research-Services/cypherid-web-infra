module "s3_buckets" {
  for_each          = var.s3_buckets
  source            = "../aws-s3-private-bucket-v0.104.2" # cztack v0.104.2
  project           = var.tags.project
  env               = var.tags.env
  service           = var.tags.service
  owner             = var.tags.owner
  bucket_name       = each.value["name"]
  bucket_policy     = each.value["policy"]
  enable_versioning = true
}
