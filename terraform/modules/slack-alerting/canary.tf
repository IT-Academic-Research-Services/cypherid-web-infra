# --- Synthetic canary: scheduled Lambda GETs the public URL and emits SeqtoidSynthetics/SyntheticUp.
# --- Catches DNS/TLS/CloudFront/WAF/app-status failures that the ALB HealthyHostCount alarm cannot.

data "archive_file" "canary" {
  type        = "zip"
  source_file = "${path.module}/functions/canary.py"
  output_path = "${path.module}/.build/${var.name_prefix}-web-canary.zip"
}

resource "aws_iam_role" "canary" {
  name = "${var.name_prefix}-web-canary"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "canary" {
  name = "putmetric-and-log"
  role = aws_iam_role.canary.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        # PutMetricData cannot be scoped to a namespace by resource ARN; gate by condition instead.
        Effect    = "Allow"
        Action    = "cloudwatch:PutMetricData"
        Resource  = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = "SeqtoidSynthetics" } }
      },
    ]
  })
}

resource "aws_lambda_function" "canary" {
  # checkov:skip=CKV_AWS_117:MUST stay out of a VPC -- the canary probes the PUBLIC URL; a private-subnet Lambda could not reach it without a NAT
  # checkov:skip=CKV_AWS_173:env vars are non-secret (the public URL); default AWS-managed at-rest encryption is sufficient
  # checkov:skip=CKV_AWS_116:no DLQ -- a dropped probe is retried on the next 1-minute schedule; a DLQ would go unmonitored
  # checkov:skip=CKV_AWS_50:X-Ray tracing adds no value for a single HTTP GET
  # checkov:skip=CKV_AWS_115:no reserved concurrency -- one invocation per minute does not need a concurrency reservation
  # checkov:skip=CKV_AWS_272:code-signing not warranted for an in-repo, source-built internal function
  function_name    = "${var.name_prefix}-web-canary"
  role             = aws_iam_role.canary.arn
  runtime          = var.lambda_runtime
  handler          = "canary.handler"
  filename         = data.archive_file.canary.output_path
  source_code_hash = data.archive_file.canary.output_base64sha256
  timeout          = 15
  tags             = var.tags

  environment {
    variables = {
      CHECK_URL = var.check_url
    }
  }
}

resource "aws_cloudwatch_event_rule" "canary_schedule" {
  name                = "${var.name_prefix}-web-canary-schedule"
  description         = "Invoke the ${var.name_prefix} synthetic canary on a schedule."
  schedule_expression = var.canary_schedule
}

resource "aws_cloudwatch_event_target" "canary" {
  rule      = aws_cloudwatch_event_rule.canary_schedule.name
  target_id = "1"
  arn       = aws_lambda_function.canary.arn
}

resource "aws_lambda_permission" "canary_schedule" {
  statement_id  = "schedule-invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.canary.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.canary_schedule.arn
}
