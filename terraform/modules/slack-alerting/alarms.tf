# --- Alarm 1: no healthy web targets. Sums HealthyHostCount across BOTH blue/green target groups
# --- (FILL(...,0) so a scaled-to-zero/absent TG reads 0, not "missing"). Fires when the total < 1
# --- for 3 consecutive minutes -- i.e. the exact signature of the 2026-08-06 503 (pods 0/1). No
# --- alarm_actions: EventBridge picks up the state change and drives the Slack formatter.
resource "aws_cloudwatch_metric_alarm" "web_down" {
  alarm_name          = "${var.name_prefix}-web-DOWN-no-healthy-targets"
  alarm_description   = "No healthy ${var.env_label} web targets behind the ALB for 3 minutes (all pods failing readiness => 503). Runbook: check web pods 0/1 + /health_check; usual cause is a DB/ES/Redis dependency the readiness probe touches."
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  evaluation_periods  = 3
  treat_missing_data  = "breaching"
  tags                = var.tags

  metric_query {
    id          = "healthy_total"
    expression  = join(" + ", [for i in range(length(var.target_group_arn_suffixes)) : "FILL(tg${i}, 0)"])
    label       = "Healthy targets (all TGs)"
    return_data = true
  }

  dynamic "metric_query" {
    for_each = { for i, s in var.target_group_arn_suffixes : i => s }
    content {
      id = "tg${metric_query.key}"
      metric {
        namespace   = "AWS/ApplicationELB"
        metric_name = "HealthyHostCount"
        stat        = "Maximum"
        period      = 60
        dimensions = {
          LoadBalancer = var.alb_arn_suffix
          TargetGroup  = metric_query.value
        }
      }
    }
  }
}

# --- Alarm 2: synthetic canary. SyntheticUp < 1 for 3 consecutive minutes => the public URL is not
# --- returning 2xx/3xx (DNS/TLS/routing/app). treat_missing_data=breaching so a dead canary (no
# --- data) also alarms rather than going silent.
resource "aws_cloudwatch_metric_alarm" "canary_down" {
  alarm_name          = "${var.name_prefix}-web-canary-DOWN"
  alarm_description   = "Synthetic canary could not reach ${var.check_url} (2xx/3xx) for 3 minutes. Runbook: curl the URL; check DNS, ACM cert, CloudFront/ALB, WAF, then the app."
  namespace           = "SeqtoidSynthetics"
  metric_name         = "SyntheticUp"
  dimensions          = { Url = var.check_url }
  statistic           = "Minimum"
  period              = 60
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  evaluation_periods  = 3
  treat_missing_data  = "breaching"
  tags                = var.tags
}
