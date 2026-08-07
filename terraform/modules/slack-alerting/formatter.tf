# --- Formatter Lambda: EventBridge (any alarm state-change with our name prefix) -> this Lambda
# --- -> sns.publish(clean message). EventBridge (not an SNS alarm action) is deliberate: it lets
# --- the Lambda REWRITE the payload, so the raw CloudWatch alarm email (which Slack drops) is
# --- never sent -- only the formatted one is.

data "archive_file" "formatter" {
  type        = "zip"
  source_file = "${path.module}/functions/alert_formatter.py"
  output_path = "${path.module}/.build/${var.name_prefix}-alert-formatter.zip"
}

resource "aws_iam_role" "formatter" {
  name = "${var.name_prefix}-alert-formatter"
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

resource "aws_iam_role_policy" "formatter" {
  name = "publish-and-log"
  role = aws_iam_role.formatter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        # Required to publish to the SSE-enabled topic (alias/aws/sns). Constrained to SNS use in
        # this region via kms:ViaService so it is not unconstrained write access (CKV_AWS_111).
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = { "kms:ViaService" = "sns.${var.region}.amazonaws.com" }
        }
      },
    ]
  })
}

resource "aws_lambda_function" "formatter" {
  # checkov:skip=CKV_AWS_117:not in a VPC by design -- it calls the public SNS endpoint; a VPC would need a NAT/endpoint for no benefit
  # checkov:skip=CKV_AWS_173:env vars are non-secret (topic ARN, env label); default AWS-managed at-rest encryption is sufficient
  # checkov:skip=CKV_AWS_116:no DLQ -- EventBridge retries delivery, and this is best-effort alerting; a DLQ would itself go unmonitored
  # checkov:skip=CKV_AWS_50:X-Ray tracing adds no value for a single-call, no-downstream formatter
  # checkov:skip=CKV_AWS_115:no reserved concurrency -- alarm state-changes are low-volume and reserving concurrency needlessly consumes the account pool
  # checkov:skip=CKV_AWS_272:code-signing not warranted for an in-repo, source-built internal function
  function_name    = "${var.name_prefix}-alert-formatter"
  role             = aws_iam_role.formatter.arn
  runtime          = var.lambda_runtime
  handler          = "alert_formatter.handler"
  filename         = data.archive_file.formatter.output_path
  source_code_hash = data.archive_file.formatter.output_base64sha256
  timeout          = 15
  tags             = var.tags

  environment {
    variables = {
      TOPIC_ARN = aws_sns_topic.alerts.arn
      ENV_LABEL = var.env_label
    }
  }
}

# Fire on ANY CloudWatch alarm whose name starts with our prefix -> covers the web-DOWN alarm,
# the canary alarm, and any future "<prefix>-*" alarm with zero extra wiring.
resource "aws_cloudwatch_event_rule" "alarms" {
  name        = "${var.name_prefix}-alarm-formatter"
  description = "Route ${var.name_prefix}-* CloudWatch alarm state changes to the Slack formatter Lambda."

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      alarmName = [{ prefix = "${var.name_prefix}-" }]
    }
  })
}

resource "aws_cloudwatch_event_target" "formatter" {
  rule      = aws_cloudwatch_event_rule.alarms.name
  target_id = "formatter"
  arn       = aws_lambda_function.formatter.arn
}

resource "aws_lambda_permission" "formatter_events" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.formatter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarms.arn
}
