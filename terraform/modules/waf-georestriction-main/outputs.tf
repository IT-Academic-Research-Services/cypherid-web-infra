output "arn" {
  description = "The ARN of the WAFv2 rule group."
  value       = aws_wafv2_rule_group.geo_restriction.arn
}

output "name" {
  description = "The name of the WAFv2 rule group."
  value       = aws_wafv2_rule_group.geo_restriction.name
}
