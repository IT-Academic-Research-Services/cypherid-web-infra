# Big contiguous node subnets for Karpenter -- the endgame for the 2026-07-15 CNI 3-ENI-death /
# subnet-exhaustion incident (platform-overhaul #699; see ENDGAME-EKS-NODE-NETWORKING-2026-07-15.md).
#
# WHY: the shared dev /24 private subnets (10.132.101/102.0/24) are too small and fragment under
# preview-sandbox spot churn. That starved IPs, and -- combined with the CNI keeping a spare ENI --
# pushed small nodes to a 3rd ENI, which broke their dataplane (nodes went NotReady ~10min after boot).
# It also blocks VPC-CNI PREFIX DELEGATION, which needs contiguous /28 blocks the churned /24s lack.
#
# FIX: give Karpenter big /18 subnets (16,384 IPs / 1,024 /28 prefixes each) carved from the empty part
# of the primary 10.132.0.0/16. With this much contiguous space, prefix delegation (the final rollout
# step) lets a node run all its pods on ONE ENI -- it never reaches the fatal 3rd ENI and the subnet
# cannot exhaust. Both subnets route through the existing private NAT route table (egress unchanged).

locals {
  # AZ -> CIDR, carved from the free space in 10.132.0.0/16. The existing subnets sit at 3rd-octets
  # .1/.2 (public), .101/.102 (private nodes), .201/.202 (db). A /18 spans 64 3rd-octet values, so the
  # only /18 that avoids all of those is .128-.191 (2b). 2a therefore uses a /19 in the clear .64-.95
  # block (8,192 IPs / 512 /28 prefixes -- still ample for prefix delegation at dev scale).
  karpenter_node_subnets = {
    "us-west-2a" = "10.132.64.0/19"  # .64-.95, free
    "us-west-2b" = "10.132.128.0/18" # .128-.191, free
  }
}

# The existing shared private route table (default route -> NAT gateway). Reused as-is so the new
# node subnets get identical egress; no new NAT, no new routing.
data "aws_route_table" "private" {
  vpc_id = local.vpc_id
  filter {
    name   = "tag:Name"
    values = ["idseq-dev-private"]
  }
}

resource "aws_subnet" "karpenter_node" {
  for_each          = local.karpenter_node_subnets
  vpc_id            = local.vpc_id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "idseq-dev-karpenter-${each.key}"
    # Internal-facing nodes (no public IPs); mirrors the private-subnet role tagging.
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table_association" "karpenter_node" {
  for_each       = aws_subnet.karpenter_node
  subnet_id      = each.value.id
  route_table_id = data.aws_route_table.private.id
}
