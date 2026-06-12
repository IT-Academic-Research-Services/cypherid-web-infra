# Converted from seqtoid-backend/cloudformation/seqtoid-backend.yaml

resource "aws_dynamodb_table" "mailing_list" {
  name         = "seqtoid-mailing-list"
  billing_mode = "PAY_PER_REQUEST"
  # read_capacity  = 20
  # write_capacity = 20
  hash_key = "email"

  attribute {
    name = "email"
    type = "S"
  }

  # ttl {
  #   attribute_name = "TimeToExist"
  #   enabled        = true
  # }

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

resource "aws_iam_policy" "lambda" {
  name   = "seqtoid-mailing-list-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda.arn
}

resource "terraform_data" "lambda_dependencies" {
  triggers_replace = [
    md5(file("${path.module}/lambda/package.json"))
  ]

  provisioner "local-exec" {
    # NOTE: Expects node version ~ 22.20.0
    command = "cd ${path.module}/lambda && npm install --production"
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
  key          = basename(data.archive_file.lambda_zip.output_path)
  source       = data.archive_file.lambda_zip.output_path
  etag         = data.archive_file.lambda_zip.output_md5
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

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.mailing_list.function_name}"
  retention_in_days = 30
}

resource "aws_api_gateway_rest_api" "mailing_list" {
  name        = "seqtoid-mailing-list-api"
  description = "API for the SeqtoID mailing list"
}

resource "aws_api_gateway_resource" "signup" {
  rest_api_id = aws_api_gateway_rest_api.mailing_list.id
  parent_id   = aws_api_gateway_rest_api.mailing_list.root_resource_id
  path_part   = "signup"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.mailing_list.id
  resource_id   = aws_api_gateway_resource.signup.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.mailing_list.id
  resource_id             = aws_api_gateway_resource.signup.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.mailing_list.invoke_arn
}

# Create an OPTIONS method that also integrates with the Lambda function
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.mailing_list.id
  resource_id   = aws_api_gateway_resource.signup.id
  http_method   = "OPTIONS"
  authorization = "NONE"

  # REQUIRED: Explicitly tell the method to expect these headers from the browser's pre-flight request.
  request_parameters = {
    "method.request.header.Access-Control-Request-Headers" = true,
    "method.request.header.Access-Control-Request-Method"  = true,
    "method.request.header.Origin"                         = true
  }
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id             = aws_api_gateway_rest_api.mailing_list.id
  resource_id             = aws_api_gateway_resource.signup.id
  http_method             = aws_api_gateway_method.options.http_method
  integration_http_method = "POST" # Must be POST for Lambda proxy
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.mailing_list.invoke_arn
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.mailing_list.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.signup.id,
      aws_api_gateway_method.post.id,
      aws_api_gateway_integration.post.id,
      aws_api_gateway_method.options.id,
      aws_api_gateway_integration.options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id   = aws_api_gateway_rest_api.mailing_list.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "api_gateway_post" {
  statement_id  = "AllowAPIGatewayInvokePOST"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mailing_list.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mailing_list.execution_arn}/prod/POST/signup"
}

resource "aws_lambda_permission" "api_gateway_options" {
  statement_id  = "AllowAPIGatewayInvokeOPTIONS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mailing_list.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mailing_list.execution_arn}/prod/OPTIONS/signup"
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

resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.mailing_list.arn
}
