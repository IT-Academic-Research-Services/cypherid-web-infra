# Converted from seqtoid-backend/cloudformation/seqtoid-backend.yaml

resource "aws_dynamodb_table" "mailing_list" {
  name         = "seqtoid-mailing-list"
  billing_mode = "PAY_PER_REQUEST"
  # read_capacity  = 20
  # write_capacity = 20
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  # ttl {
  #   attribute_name = "TimeToExist"
  #   enabled        = true
  # }

  global_secondary_index {
    name     = "email-index"
    hash_key = "email"
    # write_capacity     = 10
    # read_capacity      = 10
    projection_type = "ALL"
    # non_key_attributes = ["id"]
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = "seqtoid-mailing-list-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "DynamoDBWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:DescribeTable",
    ]
    resources = [aws_dynamodb_table.mailing_list.arn]
  }

  statement {
    sid    = "SESSendEmail"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_permissions" {
  name   = "seqtoid-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}

resource "terraform_data" "lambda_dependencies" {
  triggers_replace = [
    md5(file("${path.module}/lambda/package.json"))
  ]

  provisioner "local-exec" {
    # TODO: Expects node version ~ 22.20.0
    command = "cd ${path.module}/lambda && npm --version && npm install --production"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/lambda.zip"
  excludes    = ["lambda.zip"]

  depends_on = [terraform_data.lambda_dependencies]
}

resource "aws_s3_object" "lambda_zip" {
  bucket       = aws_s3_bucket.maintenance_bucket.id
  key          = basename(data.archive_file.lambda_zip.output_path) # "lambda.zip"
  source       = data.archive_file.lambda_zip.output_path
  etag         = data.archive_file.lambda_zip.output_md5 # Safe dynamic hash
  content_type = "application/zip"

  depends_on = [data.archive_file.lambda_zip]
}

resource "aws_lambda_function" "mailing_list" {
  function_name = "seqtoid-mailing-list"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  timeout       = 15
  memory_size   = 256

  s3_bucket = aws_s3_bucket.maintenance_bucket.id
  s3_key    = aws_s3_object.lambda_zip.key

  environment {
    variables = {
      DYNAMO_TABLE    = aws_dynamodb_table.mailing_list.name
      NOTIFY_EMAIL    = var.notify_email
      FROM_EMAIL      = var.from_email
      ALLOWED_ORIGINS = var.allowed_origins
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/aws/lambda/${aws_lambda_function.mailing_list.function_name}"
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "seqtoid-mailing-list-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = split(",", var.allowed_origins)
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 86400
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.mailing_list.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "signup" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /signup"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mailing_list.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*/signup"
}

resource "aws_wafv2_web_acl" "mailing_list" {
  name  = "seqtoid-mailing-list-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_threshold
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "seqtoid-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "seqtoid-waf"
    sampled_requests_enabled   = true
  }
}

# resource "aws_wafv2_web_acl_association" "api_gateway" {
#   resource_arn = aws_apigatewayv2_stage.prod.arn
#   web_acl_arn  = aws_wafv2_web_acl.mailing_list.arn
# }
