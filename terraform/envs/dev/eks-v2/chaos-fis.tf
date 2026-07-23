# E4 -- AWS FIS infra-layer chaos: terminate one seqtoid-web node
# (platform-overhaul #794/#797). See deploy/chaos/DESIGN.md.
#
# BUILT, NOT APPLIED. This is the infra half of chaos engineering -- the failures Chaos
# Mesh cannot reach into (real node/EC2 termination). Hypothesis: terminating ONE web
# node, Karpenter re-provisions and the PDB + topology spread keep dev serving with no
# user-facing 503. The Chaos Mesh E1 pod-kill proves pod-level resilience; this proves
# node-level.
#
# SAFETY: FIS only terminates instances that match the target's tag filter
# (karpenter.sh/nodepool=seqtoid-web, which Karpenter sets on the web pool's instances),
# and selectionMode COUNT(1) picks exactly ONE. The stop-condition (a CloudWatch alarm --
# see the TODO) halts the experiment if the ALB starts throwing 5xx. Run it manually the
# first time (aws fis start-experiment) before ever scheduling it via EventBridge.
#
# APPLY VIA CI (Rosetta wall -- no local terraform apply on this env). This file plans
# clean but is inert until deliberately applied AND an experiment is started.

module "chaos_fis_role" {
  source = "../../../modules/chaos-fis-role"

  cluster_name = local.cluster_name
  tags         = local.tags
  # Lockstep with the terminate_one_web_node target below: the role may terminate only
  # instances tagged karpenter.sh/nodepool=seqtoid-web (the web NodePool).
  terminate_target_tag_values = ["seqtoid-web"]
}

resource "aws_fis_experiment_template" "terminate_one_web_node" {
  description = "Chaos: terminate one seqtoid-web node; validate Karpenter re-provision + PDB (platform-overhaul 797)"
  role_arn    = module.chaos_fis_role.role_arn
  tags        = merge(local.tags, { "seqtoid.io/chaos" = "e4-terminate-web-node" })

  # Fail-safe: halt the experiment the moment the seqtoid-web tier throws 5xx (the resilience
  # this test validates actually broke). Wired to the web 5xx alarm (see chaos-fis-stop-alarm.tf).
  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.web_5xx_chaos_stop.arn
  }

  # Target: exactly ONE instance in the seqtoid-web Karpenter pool.
  target {
    name           = "one-web-node"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "karpenter.sh/nodepool"
      value = "seqtoid-web"
    }
  }

  action {
    name      = "terminate-web-node"
    action_id = "aws:ec2:terminate-instances"
    target {
      key   = "Instances"
      value = "one-web-node"
    }
  }
}

output "chaos_fis_experiment_template_id" {
  description = "FIS experiment template id for the terminate-one-web-node chaos experiment. Run: aws fis start-experiment --experiment-template-id <this>."
  value       = aws_fis_experiment_template.terminate_one_web_node.id
}
