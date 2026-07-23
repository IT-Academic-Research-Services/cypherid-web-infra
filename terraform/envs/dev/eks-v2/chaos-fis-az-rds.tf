# Chaos Engine -- FIS managed-service faults: AZ interruption + Aurora RDS failover
# (platform-overhaul #794/#809). See deploy/chaos/DESIGN.md sections 8/13 and CHAOS-ENGINE.md.
#
# BUILT, NOT APPLIED. These are the two infra faults Chaos Mesh cannot reach: taking out an
# Availability Zone (Netflix "Chaos Gorilla") and failing over the Aurora writer. They reuse the
# same chaos_fis_role + the same stop-condition safety pattern as E4 (chaos-fis.tf). Plan clean
# while held; inert until deliberately applied AND an experiment is started (aws fis start-experiment).
# APPLY VIA CI (Rosetta wall). Run each ATTENDED the first time before any scheduling.

variable "chaos_az" {
  description = "The AZ to interrupt for the Chaos-Gorilla experiment (one of the web pool's AZs)."
  type        = string
  default     = "us-west-2a"
}

variable "aurora_cluster_id" {
  description = "Dev Aurora cluster identifier for the RDS-failover experiment. Confirm before applying."
  type        = string
  default     = "idseq-dev" # confirmed 2026-07-22 via describe-db-clusters
}

# --- Chaos Gorilla: interrupt ONE AZ's worth of web nodes ---------------------------------------
# Hypothesis: losing every web node in one AZ, the surviving AZ + Karpenter keep dev serving with no
# user-facing 503 (topology spread guarantees pods are not all in one AZ). stop instances (not
# terminate) so recovery is a start, and the blast is bounded to one AZ.
resource "aws_fis_experiment_template" "interrupt_one_az" {
  description = "Chaos Gorilla: stop all seqtoid-web nodes in one AZ; validate cross-AZ survival (platform-overhaul 809)"
  role_arn    = module.chaos_fis_role.role_arn
  tags        = merge(local.tags, { "seqtoid.io/chaos" = "e-az-interruption" })

  stop_condition {
    source = "none" # TODO wire the ALB 5xx CloudWatch alarm (see chaos-fis.tf) before the first real run
  }

  target {
    name           = "web-nodes-in-one-az"
    resource_type  = "aws:ec2:instance"
    selection_mode = "ALL" # every matching instance IN THE FILTERED AZ (not the whole fleet)

    resource_tag {
      key   = "karpenter.sh/nodepool"
      value = "seqtoid-web"
    }
    # Narrow the blast to a single AZ -- this is what makes it "one AZ" not "all web nodes".
    filter {
      path   = "Placement.AvailabilityZone"
      values = [var.chaos_az]
    }
    # Only touch running instances.
    filter {
      path   = "State.Name"
      values = ["running"]
    }
  }

  action {
    name      = "stop-az-web-nodes"
    action_id = "aws:ec2:stop-instances"
    target {
      key   = "Instances"
      value = "web-nodes-in-one-az"
    }
    # Auto-restart after the fault window so the AZ recovers without manual action.
    parameter {
      key   = "startInstancesAfterDuration"
      value = "PT5M"
    }
  }
}

# --- Aurora RDS failover -------------------------------------------------------------------------
# Hypothesis: failing over the Aurora writer, the app reconnects within tolerance and loses no
# committed data. This is the managed-DB fault behind the "reconnect storm" class; the dual-gate
# accuracy check (a benchmark + checksum-fingerprint) proves zero data loss, not just "it came back".
resource "aws_fis_experiment_template" "aurora_failover" {
  description = "Chaos: fail over the dev Aurora cluster; validate app reconnect + zero data loss (platform-overhaul 809)"
  role_arn    = module.chaos_fis_role.role_arn
  tags        = merge(local.tags, { "seqtoid.io/chaos" = "e-rds-failover" })

  stop_condition {
    source = "none" # TODO wire a DB-connection-errors CloudWatch alarm before the first real run
  }

  target {
    name           = "dev-aurora-cluster"
    resource_type  = "aws:rds:cluster"
    selection_mode = "ALL"
    resource_arns  = ["arn:aws:rds:us-west-2:491013321714:cluster:${var.aurora_cluster_id}"]
  }

  action {
    name      = "failover-aurora"
    action_id = "aws:rds:failover-db-cluster"
    target {
      key   = "Clusters"
      value = "dev-aurora-cluster"
    }
  }
}

output "chaos_fis_az_interruption_template_id" {
  description = "FIS template id for the AZ-interruption (Chaos Gorilla) experiment."
  value       = aws_fis_experiment_template.interrupt_one_az.id
}

output "chaos_fis_aurora_failover_template_id" {
  description = "FIS template id for the Aurora failover experiment."
  value       = aws_fis_experiment_template.aurora_failover.id
}
