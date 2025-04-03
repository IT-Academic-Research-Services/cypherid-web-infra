output "elasticsearch_domain_name" {
  value = aws_elasticsearch_domain.es.domain_name
}

output "elasticsearch_domain_arn" {
  value = aws_elasticsearch_domain.es.arn
}

output "elasticsearch_endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}

output "kibana_endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}

output "elasticsearch_security_group_id" {
  value = module.es-sg.security_group_id
}

output "elasticsearch_lambda_role_arn" {
  value = aws_iam_role.lambda_es_role.arn
}
