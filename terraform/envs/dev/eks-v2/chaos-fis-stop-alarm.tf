# --- FIS stop-condition: web 5xx CloudWatch alarm ------------------------------------------------
# Auto-halts a running FIS chaos experiment the moment the seqtoid-web tier starts throwing 5xx --
# i.e. the resilience the experiment is validating actually broke. Wired as the stop_condition on
# terminate_one_web_node, interrupt_one_az, and aurora_failover. Before this, all three ran with
# source = "none" (no auto-halt): you had to watch the experiment and abort it by hand.
#
# The seqtoid-web ingress ALB is created by the AWS Load Balancer Controller from the k8s Ingress,
# so it is not a terraform resource here -- look it up by the controller's cluster/stack tags.
data "aws_lb" "seqtoid_web" {
  tags = {
    "elbv2.k8s.aws/cluster" = "czid-dev-eks-v2"
    "ingress.k8s.aws/stack" = "seqtoid-dev/czid-dev-seqtoid-web"
  }
}

resource "aws_cloudwatch_metric_alarm" "web_5xx_chaos_stop" {
  alarm_name          = "seqtoid-dev-web-5xx-chaos-stop"
  alarm_description   = "FIS stop-condition: seqtoid-web 5xx per minute (ALB-generated + target) over threshold during a chaos experiment -> auto-halt. ALB 5xx = the load balancer cannot reach healthy backends (node/AZ loss); target 5xx = the app itself is erroring (e.g. a botched DB failover)."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 10 # >10 web 5xx in a 60s window during an experiment = steady state broke
  treat_missing_data  = "notBreaching"
  tags                = merge(local.tags, { "seqtoid.io/chaos" = "stop-condition" })

  # Sum the two 5xx classes so the halt fires whether the LB can't reach the backend OR the app
  # returns 500s.
  metric_query {
    id          = "total5xx"
    expression  = "elb5xx + tgt5xx"
    label       = "web 5xx/min (ALB + target)"
    return_data = true
  }
  metric_query {
    id = "elb5xx"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      dimensions  = { LoadBalancer = data.aws_lb.seqtoid_web.arn_suffix }
      period      = 60
      stat        = "Sum"
    }
  }
  metric_query {
    id = "tgt5xx"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = { LoadBalancer = data.aws_lb.seqtoid_web.arn_suffix }
      period      = 60
      stat        = "Sum"
    }
  }
}

output "chaos_fis_stop_alarm_arn" {
  description = "CloudWatch alarm ARN used as the FIS chaos stop-condition (web 5xx). Referenced by the FIS experiment templates' stop_condition blocks."
  value       = aws_cloudwatch_metric_alarm.web_5xx_chaos_stop.arn
}
