locals {
  # This component runs under envs/dev (dev account/profile/VPC), but every resource it creates is
  # for the SANDBOX tier. `tier` is the naming/SSM token so nothing collides with the dev heatmap
  # domain's resources, and the SSM params land under /idseq-sandbox-web/ (the shared sandbox path
  # that lib/tasks/sandbox.rake reads to override each per-PR sandbox's HEATMAP_ES_ADDRESS).
  tier    = "sandbox"
  service = "es"
  name    = "${var.project}-${local.tier}-${local.service}"
  tags = {
    managedBy = "terraform"
    Name      = local.name
    project   = var.project
    env       = local.tier
    service   = local.service
    owner     = var.owner
  }
}

# Publish the sandbox domain endpoint to /idseq-sandbox-web/ (ES_ADDRESS + HEATMAP_ES_ADDRESS).
# sandbox.rake copies these into each per-PR sandbox's chamber, so sandbox pods + the sandbox-stage
# taxon-indexing lambdas read/write THIS domain, never dev's.
module "idseq-heatmap-es-param" {
  source  = "../../../modules/aws-ssm-params-writer-v0.104.2" # cztack v0.104.2
  project = var.project
  env     = local.tier
  service = "web"
  owner   = var.owner

  parameters = {
    ES_ADDRESS         = "https://${module.elasticsearch.elasticsearch_endpoint}"
    HEATMAP_ES_ADDRESS = "https://${module.elasticsearch.elasticsearch_endpoint}"
  }
}
