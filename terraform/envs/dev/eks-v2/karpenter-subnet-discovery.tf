# Karpenter subnet discovery for THIS cluster (czid-dev-eks-v2).
#
# The tag itself now lives in `aws_subnet.karpenter_node.tags` (eks-node-subnets.tf). It is NOT
# managed here any more; this file exists only to retire the old resource safely.
#
# WHY IT MOVED: `aws_ec2_tag` managed `karpenter.sh/discovery/<cluster>` on the very subnets this
# module declares. `aws_subnet.tags` is AUTHORITATIVE -- it removes any tag not in its map -- so
# every apply stripped this tag and aws_ec2_tag re-added it. The two ping-ponged forever and the
# plan NEVER CONVERGED: it alternated between "aws_subnet.karpenter_node updated in-place" and
# "aws_ec2_tag.karpenter_subnet_discovery created" depending on who ran last. That is the "will
# recur" recorded against #21 -- applying it did not fix it, because the config could not settle.
#
# It was never cosmetic. On 2026-07-16 an apply stripped the tag, term 2 of the EC2NodeClass
# subnetSelectorTerms went dead, and Karpenter silently fell back to term 1 -- the shared /24s
# whose fragmentation drove the 2026-07-15 CNI node-death incident (#699). Every node relaunched
# into the small subnets. Nothing errored, no pods pended, and the /18 fix was simply inactive.
# A perpetual diff that flips a live selector is an outage waiting for a quiet apply.
#
# `aws_ec2_tag` is the right tool ONLY for resources a module does not own (e.g. the shared /24s).
# This module owns these subnets, so the tag belongs in their tag map: one owner, no conflict.
#
# `destroy = false` is load-bearing. A plain removal would make Terraform issue DeleteTags for this
# key, which -- depending on apply ordering against the aws_subnet update -- could delete the tag
# the subnet just set and recreate the very outage this change exists to prevent. This drops the
# resource from state without touching AWS and leaves the live tag owned by aws_subnet.
#
# Safe to delete this block once applied everywhere (state no longer references the resource).
removed {
  from = aws_ec2_tag.karpenter_subnet_discovery

  lifecycle {
    destroy = false
  }
}
