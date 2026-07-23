# Chaos Engine pipeline sandbox -- AWS FIS experiment templates for P2/P4/P5/P6 (platform-overhaul #794/#808).
#
# These are the AWS-native fault definitions the pipeline P-series experiments start (the P*.yaml
# inject nodes call `aws fis start-experiment` against these by Name tag). They are authored here as a
# standalone, apply-via-CI module -- NOT wired to a backend and NOT applied. Everything is inert unless
# var.enable_chaos_fis is explicitly set true AND var.deployment_environment == "dev-chaos".
#
# ISOLATION: every template targets ONLY resources/roles carrying seqtoid.io/chaos-sandbox=true (the tag
# that cypherid-workflow-infra/main.tf applies exclusively to the dev-chaos stack). FIS itself therefore
# cannot reach a shared idseq-dev-* resource, independent of the in-cluster guard.
#
# HONEST GAPS (fill from the sandbox terraform outputs once it is applied -- do NOT guess ARNs):
#   - var.sandbox_batch_job_role_arn  : the idseq-dev-chaos Batch JOB role (S3 calls)  -> P4
#   - var.sandbox_sfn_execution_role_arn : the idseq-dev-chaos SFN execution role      -> P5
#   - var.sandbox_batch_instance_role_arn : the idseq-dev-chaos Batch INSTANCE role    -> P6
#   - var.stop_condition_alarm_arn    : a CloudWatch alarm to auto-stop on (optional)   -> all
# The P2 spot template needs no role ARN (it targets Spot instances by tag directly).
#
# Apply (via CI, into the dev account, after the sandbox exists):
#   terraform init && terraform apply -var enable_chaos_fis=true -var deployment_environment=dev-chaos \
#     -var 'sandbox_batch_job_role_arn=...' -var 'sandbox_sfn_execution_role_arn=...' \
#     -var 'sandbox_batch_instance_role_arn=...'

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
  }
  # No backend block on purpose: wire a dev-chaos-scoped backend (own state key) when this is
  # promoted into the sandbox apply. TODO: add backend "s3" with key = idseqdev-chaos-fis.
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "deployment_environment" {
  type    = string
  default = "dev-chaos"
  validation {
    # Hard stop: these templates may only ever be built for the dev-chaos sandbox.
    condition     = var.deployment_environment == "dev-chaos"
    error_message = "FIS chaos templates are dev-chaos only; refuse to build them for any other environment."
  }
}

variable "enable_chaos_fis" {
  type        = bool
  default     = false
  description = "Master switch. Left false so the templates are inert until Tom arms the sandbox."
}

variable "sandbox_batch_job_role_arn" {
  type        = string
  default     = "" # TODO: idseq-dev-chaos Batch job role ARN (from sandbox outputs). P4.
  description = "IAM role whose S3 API calls P4 faults. Empty => P4 template is not created."
}

variable "sandbox_sfn_execution_role_arn" {
  type        = string
  default     = "" # TODO: idseq-dev-chaos SFN execution role ARN. P5.
  description = "IAM role whose Batch API calls P5 throttles. Empty => P5 template is not created."
}

variable "sandbox_batch_instance_role_arn" {
  type        = string
  default     = "" # TODO: idseq-dev-chaos Batch instance role ARN. P6.
  description = "IAM role whose ECR pulls P6 throttles. Empty => P6 template is not created."
}

variable "stop_condition_alarm_arn" {
  type        = string
  default     = "" # TODO: wire the SLO-breach CloudWatch alarm; empty => stopCondition source=none.
  description = "Optional CloudWatch alarm ARN that auto-stops any running experiment on SLO breach."
}

locals {
  armed       = var.enable_chaos_fis
  chaos_tag   = "seqtoid.io/chaos-sandbox"
  common_tags = { "seqtoid.io/chaos-sandbox" = "true" }
  stop_conditions = var.stop_condition_alarm_arn == "" ? [{ source = "none", value = null }] : [{
    source = "aws:cloudwatch:alarm"
    value  = var.stop_condition_alarm_arn
  }]
}

# FIS service role: the role FIS assumes to inject faults. Least-privilege is refined per action;
# kept minimal + tag-conditioned here. Created only when armed.
data "aws_iam_policy_document" "fis_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fis" {
  count              = local.armed ? 1 : 0
  name               = "idseq-dev-chaos-fis-role"
  assume_role_policy = data.aws_iam_policy_document.fis_assume.json
  tags               = local.common_tags
}

# NOTE: attach the AWS-managed FIS access policies (AWSFaultInjectionSimulatorEC2Access,
# ...NetworkAccess, and an inline policy for fis:InjectApi* on the sandbox roles) to aws_iam_role.fis
# before first run. Left as a TODO so this file cannot over-grant on a blind apply.

# ---------------------------------------------------------------------------------------------------
# P2 -- Spot interruption. Targets sandbox Spot instances by tag; no role needed.
# ---------------------------------------------------------------------------------------------------
resource "aws_fis_experiment_template" "p2_spot_interrupt" {
  count       = local.armed ? 1 : 0
  description = "Chaos Engine P2: interrupt one sandbox Spot instance mid-task; assert Batch/SFN retry + AUPR."
  role_arn    = aws_iam_role.fis[0].arn
  tags        = merge(local.common_tags, { Name = "idseq-dev-chaos-fis-p2-spot-interrupt" })

  dynamic "stop_condition" {
    for_each = local.stop_conditions
    content {
      source = stop_condition.value.source
      value  = stop_condition.value.value
    }
  }

  action {
    name      = "interrupt-spot"
    action_id = "aws:ec2:send-spot-instance-interruptions"
    target {
      key   = "SpotInstances"
      value = "sandbox-spot"
    }
    parameter {
      key   = "durationBeforeInterruption"
      value = "PT2M"
    }
  }

  target {
    name           = "sandbox-spot"
    resource_type  = "aws:ec2:spot-instance"
    selection_mode = "COUNT(1)" # one instance -- transient, minimal blast
    resource_tag {
      key   = local.chaos_tag
      value = "true"
    }
  }
}

# ---------------------------------------------------------------------------------------------------
# P4 -- S3 API errors on the sandbox Batch JOB role. Created only if the role ARN is provided.
# ---------------------------------------------------------------------------------------------------
resource "aws_fis_experiment_template" "p4_s3_fault" {
  count       = local.armed && var.sandbox_batch_job_role_arn != "" ? 1 : 0
  description = "Chaos Engine P4: inject S3 internal errors on sandbox pipeline S3 calls; assert retries + AUPR."
  role_arn    = aws_iam_role.fis[0].arn
  tags        = merge(local.common_tags, { Name = "idseq-dev-chaos-fis-p4-s3-fault" })

  dynamic "stop_condition" {
    for_each = local.stop_conditions
    content {
      source = stop_condition.value.source
      value  = stop_condition.value.value
    }
  }

  action {
    name      = "s3-internal-error"
    action_id = "aws:fis:inject-api-internal-error"
    target {
      key   = "Roles"
      value = "sandbox-batch-job-role"
    }
    parameter {
      key   = "service"
      value = "s3"
    }
    parameter {
      key   = "operations"
      value = "GetObject,PutObject"
    }
    parameter {
      key   = "percentage"
      value = "20"
    }
    parameter {
      key   = "duration"
      value = "PT10M"
    }
  }

  target {
    name           = "sandbox-batch-job-role"
    resource_type  = "aws:iam:role"
    selection_mode = "ALL"
    resource_arns  = [var.sandbox_batch_job_role_arn]
  }
}

# ---------------------------------------------------------------------------------------------------
# P5 -- Batch API throttling on the sandbox SFN execution role (forces a task-transition fault).
# ---------------------------------------------------------------------------------------------------
resource "aws_fis_experiment_template" "p5_sfn_task_fault" {
  count       = local.armed && var.sandbox_sfn_execution_role_arn != "" ? 1 : 0
  description = "Chaos Engine P5: throttle Batch API for the sandbox SFN role; assert SFN Retry/Catch + AUPR."
  role_arn    = aws_iam_role.fis[0].arn
  tags        = merge(local.common_tags, { Name = "idseq-dev-chaos-fis-p5-sfn-task-fault" })

  dynamic "stop_condition" {
    for_each = local.stop_conditions
    content {
      source = stop_condition.value.source
      value  = stop_condition.value.value
    }
  }

  action {
    name      = "batch-throttle"
    action_id = "aws:fis:inject-api-throttle-error"
    target {
      key   = "Roles"
      value = "sandbox-sfn-role"
    }
    parameter {
      key   = "service"
      value = "batch"
    }
    parameter {
      key   = "operations"
      value = "SubmitJob,DescribeJobs"
    }
    parameter {
      key   = "percentage"
      value = "50"
    }
    parameter {
      key   = "duration"
      value = "PT10M"
    }
  }

  target {
    name           = "sandbox-sfn-role"
    resource_type  = "aws:iam:role"
    selection_mode = "ALL"
    resource_arns  = [var.sandbox_sfn_execution_role_arn]
  }
}

# ---------------------------------------------------------------------------------------------------
# P6 -- ECR API throttling on the sandbox Batch INSTANCE role (assert cached layers absorb it).
# ---------------------------------------------------------------------------------------------------
resource "aws_fis_experiment_template" "p6_ecr_throttle" {
  count       = local.armed && var.sandbox_batch_instance_role_arn != "" ? 1 : 0
  description = "Chaos Engine P6: throttle ECR API for the sandbox instance role; assert run slows not fails + AUPR."
  role_arn    = aws_iam_role.fis[0].arn
  tags        = merge(local.common_tags, { Name = "idseq-dev-chaos-fis-p6-ecr-throttle" })

  dynamic "stop_condition" {
    for_each = local.stop_conditions
    content {
      source = stop_condition.value.source
      value  = stop_condition.value.value
    }
  }

  action {
    name      = "ecr-throttle"
    action_id = "aws:fis:inject-api-throttle-error"
    target {
      key   = "Roles"
      value = "sandbox-instance-role"
    }
    parameter {
      key   = "service"
      value = "ecr"
    }
    parameter {
      key   = "operations"
      value = "GetDownloadUrlForLayer,BatchGetImage"
    }
    parameter {
      key   = "percentage"
      value = "70"
    }
    parameter {
      key   = "duration"
      value = "PT10M"
    }
  }

  target {
    name           = "sandbox-instance-role"
    resource_type  = "aws:iam:role"
    selection_mode = "ALL"
    resource_arns  = [var.sandbox_batch_instance_role_arn]
  }
}
