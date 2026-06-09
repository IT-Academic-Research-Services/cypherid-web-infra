locals {
  name          = "${var.tags.project}-${var.tags.env}-${var.tags.service}"
  namespace     = coalesce(var.default_namespace, "${var.tags.project}-${var.tags.env}")
  iam_role_path = coalesce(var.iam_role_path, "/${var.eks_cluster.cluster_id}-k8s-core/")
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "kubernetes_namespace" "k8s_core_namespace" {
  metadata {
    annotations = {
      # local.iam_role_path has leading slash, so this does not include it in the string template, unlike other places
      "iam.amazonaws.com/permitted" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role${local.iam_role_path}.*"
    }

    name = var.k8s_core_namespace
  }
}

resource "kubernetes_namespace" "default_namespace" {
  metadata {
    annotations = {
      "iam.amazonaws.com/permitted" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.eks_cluster.cluster_id}/.*"
    }

    name = local.namespace
  }
}