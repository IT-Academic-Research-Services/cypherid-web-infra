# EKS access entries for czid-dev-eks-v2 (SMP-1640).
#
# WHY: aws-auth ConfigMap authentication is deprecated by AWS. Access entries are
# the replacement: cluster authorization becomes a first-class AWS API object
# instead of a hand-edited ConfigMap that can lock everyone out if it is corrupted.
#
# THIS FILE IS ADDITIVE AND DOES NOT REMOVE ANYTHING. The shared cluster module
# still sets manage_aws_auth_configmap = true (terraform/modules/
# aws-eks-cluster-v0.104.2/main.tf), so every mapping below continues to exist in
# aws-auth as well. Under authenticationMode = API_AND_CONFIG_MAP both mechanisms
# are consulted, so the two coexist and the access entry is the belt to aws-auth's
# braces. Retiring the ConfigMap path is deliberately a SEPARATE change: that
# module is shared by dev, staging, prod and sandbox, so flipping it there would
# hit every environment at once.
#
# HARD PREREQUISITE, out of band, before this file can apply:
#   aws eks update-cluster-config --name czid-dev-eks-v2 --region us-west-2 \
#     --access-config authenticationMode=API_AND_CONFIG_MAP
# The cluster is currently authenticationMode = CONFIG_MAP, and in that mode the
# EKS API REJECTS every access-entry call outright ("The cluster's authentication
# mode must be set to one of [API, API_AND_CONFIG_MAP]"). Applying this file
# first therefore fails. The flip cannot be expressed in terraform here: this
# stack calls the vendored aws-eks-cluster-v0.104.2 module, which pins upstream
# terraform-aws-modules/eks/aws v19.16.0, and v19 has no access_config block. The
# flip is also ONE-WAY: AWS does not allow going back to CONFIG_MAP. Because v19
# never reads the attribute, the flip is invisible to terraform and produces no
# drift.
#
# WHAT IS DELIBERATELY NOT DECLARED HERE: the managed node group role
# (czid-dev-eks-v2-eks-node*) and the Karpenter Fargate profile pod execution
# role (karpenter-*). EKS creates and owns EC2_LINUX / FARGATE_LINUX access
# entries for managed node groups and Fargate profiles automatically once the
# cluster is in API_AND_CONFIG_MAP. Declaring them here would collide with the
# AWS-managed entries and fail the apply. Verify they appeared after the flip:
#   aws eks list-access-entries --cluster-name czid-dev-eks-v2 --region us-west-2
# The Karpenter NODE role below is different and IS declared: Karpenter nodes are
# self-managed EC2 instances, not a managed node group, so AWS creates nothing
# for them and they would fail to join the cluster without an explicit entry.

locals {
  # Every principal ARN below is rebuilt in the path-less "role/<name>" form.
  # Two reasons: local.owner_roles / local.read_only_roles hold role NAMES, and
  # the EKS access entry API stores principals without an IAM path. The AWS SSO
  # role in local.owner_roles really lives at
  # role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_*, so feeding
  # its full ARN in would not match what EKS records and every plan would show a
  # phantom change. Partition and account are taken from the cluster's own ARN,
  # which also gives these resources their dependency on the cluster existing.
  eks_partition  = split(":", module.eks-cluster.cluster_arn)[1]
  eks_account_id = split(":", module.eks-cluster.cluster_arn)[4]

  # Mirrors local.argo_child_role_name in the cluster module
  # (terraform/modules/aws-eks-cluster-v0.104.2/argo_child_role.tf), which is not
  # exported. Resolves to argo_child_idseq_dev_eks_v2, matching the live role.
  argo_child_role_name = "argo_child_${replace("${local.tags.project}_${local.tags.env}_${local.tags.service}", "-", "_")}"

  # Cluster administrators. Sourced from local.owner_roles so that adding an
  # owner role stays a one-line edit that updates aws-auth and access entries
  # together, plus the Argo CD child role that the module maps separately.
  cluster_admin_role_names = toset(concat(local.owner_roles, [local.argo_child_role_name]))

  karpenter_node_role_name = "karpenter-${local.cluster_name}"
}

# Admin principals: CI apply/executor roles, the SSO administrator role, the
# poweruser role and Argo CD. These hold system:masters via aws-auth today;
# AmazonEKSClusterAdminPolicy is the access-entry equivalent.
resource "aws_eks_access_entry" "cluster_admin" {
  for_each = local.cluster_admin_role_names

  cluster_name  = local.cluster_name
  principal_arn = format("arn:%s:iam::%s:role/%s", local.eks_partition, local.eks_account_id, each.value)
  type          = "STANDARD"
  tags          = local.tags
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = local.cluster_admin_role_names

  cluster_name  = local.cluster_name
  principal_arn = aws_eks_access_entry.cluster_admin[each.value].principal_arn
  policy_arn    = "arn:${local.eks_partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Read-only principals: the terraform PLAN role.
#
# This binds to the eks-readonly-group Kubernetes group rather than attaching
# AmazonEKSViewPolicy, and that is deliberate. The module already creates an
# eks-readonly ClusterRole plus a binding for that group granting get/list/watch
# on ALL resources, and the plan role NEEDS that breadth: the helm provider keeps
# release state in Secrets, so a refresh that cannot read Secrets fails the whole
# eks-v2 plan with Unauthorized (see the rationale on local.read_only_roles in
# variables.tf). AmazonEKSViewPolicy is modelled on the built-in "view"
# ClusterRole, which excludes Secrets, so using it here would silently break
# plan the moment aws-auth is retired in phase 2. Binding the existing group
# reproduces today's permissions exactly.
resource "aws_eks_access_entry" "cluster_readonly" {
  for_each = toset(local.read_only_roles)

  cluster_name  = local.cluster_name
  principal_arn = format("arn:%s:iam::%s:role/%s", local.eks_partition, local.eks_account_id, each.value)
  type          = "STANDARD"
  # Matches kubernetes_cluster_role_binding_v1.eks-readonly.subject[0].name in the
  # cluster module, which is not exported from it. Confirmed against the live
  # aws-auth mapping for czid-dev-gh-actions-plan.
  kubernetes_groups = ["eks-readonly-group"]
  tags              = local.tags
}

# Karpenter node role. Karpenter launches self-managed EC2 instances, so AWS
# creates no automatic entry for this role; without it, nodes that Karpenter
# provisions cannot register once aws-auth is retired.
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = local.cluster_name
  principal_arn = format("arn:%s:iam::%s:role/%s", local.eks_partition, local.eks_account_id, local.karpenter_node_role_name)
  type          = "EC2_LINUX"
  tags          = local.tags
}
