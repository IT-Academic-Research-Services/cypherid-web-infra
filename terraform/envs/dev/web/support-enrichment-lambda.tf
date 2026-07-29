# Support-enrichment lambda -- Phase 2 (L2/L3) of the support pipeline-failure
# enrichment. See docs/support-pipeline-failure-enrichment.md in seqtoid-web.
#
# WHY self-contained here: pipeline lambdas normally live in cypherid-workflow-infra,
# but that root is undeployed (0 runs, large backlog) -- a landmine to apply. This
# function is defined self-contained in the web env so it is actually applyable, right
# next to the seqtoid-web role it serves.
#
# LEAST PRIVILEGE: this function's OWN role holds the scoped states:/logs: read; the
# seqtoid-web role gets ONLY lambda:InvokeFunction on this one function. Redaction
# happens in the handler, so nothing unredacted returns to the app.

variable "pipeline_log_group" {
  type        = string
  description = "CloudWatch log group of the pipeline Batch jobs the enrichment tails (L3). TODO(review): confirm the exact per-env group name."
  default     = "/aws/batch/job"
}

locals {
  support_enrichment_fn_name = "seqtoid-web-${var.env}-support-enrichment"
  swipe_execution_arn        = "arn:aws:states:${var.region}:${data.aws_caller_identity.current.account_id}:execution:idseq-swipe-${var.env}-*:*"
  swipe_state_machine_arn    = "arn:aws:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:idseq-swipe-${var.env}-*"
}

data "archive_file" "support_enrichment" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda-src/support-enrichment"
  output_path = "${path.module}/.build/support-enrichment.zip"
}

# --- execution role: scoped SFN read + pipeline-log read + own logging ---
data "aws_iam_policy_document" "support_enrichment_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "support_enrichment" {
  name               = "${local.support_enrichment_fn_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.support_enrichment_trust.json
}

data "aws_iam_policy_document" "support_enrichment_perms" {
  statement {
    sid       = "DescribeSwipeExecutions"
    actions   = ["states:DescribeExecution", "states:GetExecutionHistory"]
    resources = [local.swipe_execution_arn, local.swipe_state_machine_arn]
  }
  statement {
    sid       = "ReadPipelineLogs"
    actions   = ["logs:FilterLogEvents", "logs:GetLogEvents"]
    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.pipeline_log_group}:*"]
  }
  # L3 resolves the failed stage's log stream via the Batch JobId. batch:DescribeJobs has
  # no resource-level scoping (AWS limitation), so it must be "*"; it is read-only and
  # returns only job metadata (the log stream name), never job data.
  statement {
    sid       = "DescribeBatchJobs"
    actions   = ["batch:DescribeJobs"]
    resources = ["*"]
  }
  statement {
    sid       = "OwnLogging"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.support_enrichment_fn_name}:*"]
  }
}

resource "aws_iam_role_policy" "support_enrichment" {
  name   = "${local.support_enrichment_fn_name}-perms"
  role   = aws_iam_role.support_enrichment.id
  policy = data.aws_iam_policy_document.support_enrichment_perms.json
}

# --- the function ---
resource "aws_lambda_function" "support_enrichment" {
  #checkov:skip=CKV_AWS_116:retry + DLQ live in the Rails SupportEnrichmentJob (Resque dead-letter); a lambda-level DLQ is redundant for this sync-invoked function
  #checkov:skip=CKV_AWS_117:no VPC resources are touched -- the function calls the SFN + CloudWatch Logs AWS APIs only
  #checkov:skip=CKV_AWS_173:environment variables are non-secret (a log-group name + a line cap); no KMS CMK is warranted
  #checkov:skip=CKV_AWS_272:code signing is not used elsewhere in this stack
  function_name                  = local.support_enrichment_fn_name
  role                           = aws_iam_role.support_enrichment.arn
  runtime                        = "python3.12"
  handler                        = "handler.handler"
  filename                       = data.archive_file.support_enrichment.output_path
  source_code_hash               = data.archive_file.support_enrichment.output_base64sha256
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 10 # bound blast radius; this is low-volume

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      PIPELINE_LOG_GROUP = var.pipeline_log_group
      MAX_LOG_LINES      = "40"
    }
  }
}

# --- grant the seqtoid-web role ONLY InvokeFunction on this one function ---
resource "aws_iam_role_policy" "seqtoid_web_invoke_support_enrichment" {
  name = "seqtoid-web-${var.env}-invoke-support-enrichment"
  role = aws_iam_role.seqtoid_web_eks.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeSupportEnrichment"
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.support_enrichment.arn
    }]
  })
}

# --- publish the ARN as the chamber/SSM param the app's feature guard reads ---
# The app (SupportEnrichmentLambda) is inert until SUPPORT_ENRICHMENT_LAMBDA_ARN is set;
# chamber exposes /idseq-${env}-web/* params as env vars in the pod. SecureString with
# the repo's parameter_store CMK matches how the other web params are written (and
# satisfies CKV_AWS_337); the web role already has kms:Decrypt for chamber.
data "aws_kms_key" "support_enrichment_param_store" {
  key_id = "alias/parameter_store_key"
}

resource "aws_ssm_parameter" "support_enrichment_lambda_arn" {
  name        = "/idseq-${var.env}-web/SUPPORT_ENRICHMENT_LAMBDA_ARN"
  description = "ARN of the support-enrichment lambda; enables the app's async L2/L3 enrichment when set."
  type        = "SecureString"
  key_id      = data.aws_kms_key.support_enrichment_param_store.id
  value       = aws_lambda_function.support_enrichment.arn
}

output "support_enrichment_lambda_arn" {
  value       = aws_lambda_function.support_enrichment.arn
  description = "ARN of the support-enrichment lambda."
}
