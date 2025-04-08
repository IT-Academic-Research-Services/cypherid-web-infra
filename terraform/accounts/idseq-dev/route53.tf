locals {
  domain = "czid.org" //TODO - change to UCSF domain once determined
}

// New zones for CZ ID

resource "aws_route53_zone" "dev-czid-org" {
  name = "dev.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "dev"
  }
}

resource "aws_route53_zone" "staging-czid-org" {
  name = "staging.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "staging"
  }
}

resource "aws_route53_zone" "sandbox-czid-org" {
  name = "sandbox.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "sandbox"
  }
}

resource "aws_route53_zone" "public-czid-org" {
  name = "public.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "public"
  }
}

// Old zones for IDseq

resource "aws_route53_zone" "dev-idseq-net" {
  name = "dev.idseq.net"
  tags = {
    owner   = var.owner
    project = var.project
    service = "idseq"
    env     = "dev"
  }
}

resource "aws_route53_zone" "staging-idseq-net" {
  name = "staging.idseq.net"
  tags = {
    owner   = var.owner
    project = var.project
    service = "idseq"
    env     = "staging"
  }
}

resource "aws_route53_zone" "sandbox-idseq-net" {
  name = "sandbox.idseq.net"
  tags = {
    owner   = var.owner
    project = var.project
    service = "idseq"
    env     = "sandbox"
  }
}

resource "aws_route53_zone" "public-idseq-net" {
  name = "public.idseq.net"
  tags = {
    owner   = var.owner
    project = var.project
    service = "idseq"
    env     = "public"
  }
}

resource "aws_route53_zone" "meta-sandbox-idseq-net" {
  name = "meta.sandbox.idseq.net"
  tags = {
    owner   = var.owner
    project = var.project
    service = "idseq"
    env     = "sandbox"
  }
}

# Zones for happy dev/sandbox/staging envs
resource "aws_route53_zone" "dev-happy-czid-org" {
  name = "dev.happy.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "dev"
  }
}

resource "aws_route53_zone" "staging-happy-czid-org" {
  name = "staging.happy.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "staging"
  }
}

resource "aws_route53_zone" "sandbox-happy-czid-org" {
  name = "sandbox.happy.${local.domain}"
  tags = {
    owner   = var.owner
    project = var.project_v1
    service = "czid"
    env     = "sandbox"
  }
}
