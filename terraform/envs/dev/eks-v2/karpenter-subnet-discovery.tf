# Karpenter subnet discovery for THIS cluster (czid-dev-eks-v2).
#
# Points Karpenter at the BIG /18 node subnets (eks-node-subnets.tf) instead of the shared dev
# /24 private subnets. The /24s were too small + fragmented and drove the 2026-07-15 CNI node-death
# incident (#699); the /18s give prefix delegation the contiguous space it needs. Existing nodes in
# the /24s keep running -- this tag only controls where NEW nodes launch -- and Karpenter cycles them
# into the big subnets over time (NodeRepair + consolidation).
#
# The EC2NodeClass matches subnets via the per-cluster unique-key tag
# `karpenter.sh/discovery/<cluster> = <cluster>`. `aws_ec2_tag` manages exactly one tag key on one
# resource, so tagging the new subnets here (and no longer the /24s) is a clean switch; the old
# cluster's own `karpenter.sh/discovery = czid-dev-eks` tag on the /24s is never touched.
resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  for_each    = aws_subnet.karpenter_node
  resource_id = each.value.id
  key         = "karpenter.sh/discovery/${local.cluster_name}"
  value       = local.cluster_name
}
