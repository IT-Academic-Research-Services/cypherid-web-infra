terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100.0"

      # This module provisions the ACM certificate in us-east-1 (required for
      # CloudFront) via an aliased provider. The caller must pass it explicitly:
      #   providers = { aws = aws, aws.us-east-1 = aws.us-east-1 }
      configuration_aliases = [aws.us-east-1]
    }
  }
}
