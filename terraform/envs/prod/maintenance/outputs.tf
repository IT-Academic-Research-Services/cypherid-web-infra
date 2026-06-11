output "api_endpoint" {
  description = "The HTTPS URL to POST form submissions to"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/signup"
}

output "dynamo_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.mailing_list.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.mailing_list.function_name
}

output "waf_web_acl_arn" {
  description = "WAF WebACL ARN"
  value       = aws_wafv2_web_acl.mailing_list.arn
}
