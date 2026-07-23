# Validation-only harness (mirrors terraform/modules/happy-env-eks/.validate).
# static-site provisions its CloudFront ACM certificate through an injected
# aws.us-east-1 provider, so a standalone `terraform validate` of the module
# fails "Provider configuration not present". This root wires empty default +
# us-east-1 aws providers so the module can be type-checked in isolation. Never
# applied — inputs are dummy placeholders.
module "test_validate" {
  source = "../../static-site"

  env     = "test"
  service = "test"
  domain  = "test.example.com"
  zone_id = "test"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}

provider "aws" {}

provider "aws" {
  alias = "us-east-1"
}
