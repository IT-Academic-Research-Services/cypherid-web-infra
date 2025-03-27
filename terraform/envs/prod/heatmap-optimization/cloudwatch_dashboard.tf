resource "aws_cloudwatch_dashboard" "heatmap_alert_dashboard" {

  dashboard_name = "${var.env}-heatmap_alert_dashboard"

  dashboard_body = <<EOF
{
    "widgets": [
        {
            "height": 6,
            "width": 6,
            "y": 1,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ { "expression": "m1/3", "label": "ClusterStatus.green", "id": "e1", "color": "#093" } ],
                    [ "AWS/ES", "ClusterStatus.green", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "color": "#dbdb8d", "yAxis": "left", "id": "m1", "visible": false } ],
                    [ "AWS/ES", "ClusterStatus.yellow", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "color": "#c7c7c7", "id": "m2", "visible": false } ],
                    [ { "expression": "m2*2/3", "label": "ClusterStatus.yellow", "id": "e2", "color": "#e07700" } ],
                    [ "AWS/ES", "ClusterStatus.red", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "id": "m3", "color": "#C00" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "title": "Cluster status",
                "fill": "Below",
                "period": 60,
                "stat": "Maximum",
                "yAxis": {
                    "left": {
                        "min": 0,
                        "max": 1,
                        "showUnits": false
                    }
                },
                "legend": {
                    "position": "hidden"
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 1,
            "x": 6,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ { "expression": "(m3*(-1))+1", "label": "ClusterIndexWritesBlocked-green", "id": "e1", "color": "#093" } ],
                    [ { "expression": "m3*2", "label": "ClusterIndexWritesBlocked-red", "id": "e2", "color": "#C00" } ],
                    [ "AWS/ES", "ClusterIndexWritesBlocked", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "id": "m3", "color": "#C00", "visible": false } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "title": "Cluster writes status",
                "fill": "Below",
                "period": 60,
                "stat": "Maximum",
                "yAxis": {
                    "left": {
                        "min": 0,
                        "max": 2,
                        "showUnits": false
                    }
                },
                "legend": {
                    "position": "hidden"
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 1,
            "x": 12,
            "type": "metric",
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/ES", "Nodes", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}" ]
                ],
                "region": "${var.region}",
                "title": "Total nodes (Count)",
                "period": 60,
                "stat": "Minimum",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 1,
            "x": 18,
            "type": "metric",
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ { "expression": "FLOOR(m1/1024)", "label": "FreeStorageSpace", "id": "e1" } ],
                    [ "AWS/ES", "FreeStorageSpace", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "id": "m1", "visible": false } ]
                ],
                "region": "${var.region}",
                "title": "Total free storage space (GiB)",
                "period": 60,
                "stat": "Sum",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 7,
            "x": 0,
            "type": "metric",
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/ES", "CPUUtilization", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}" ]
                ],
                "region": "${var.region}",
                "title": "Maximum CPU utilization (Percent)",
                "period": 60,
                "stat": "Maximum",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 7,
            "x": 6,
            "type": "metric",
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ { "expression": "FLOOR(m1/1024)", "label": "FreeStorageSpace", "id": "e1" } ],
                    [ "AWS/ES", "FreeStorageSpace", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "id": "m1", "visible": false } ]
                ],
                "region": "${var.region}",
                "title": "Minimum free storage space (GiB)",
                "period": 60,
                "stat": "Minimum",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 7,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/ES", "SearchLatency", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "title": "Search latency (Milliseconds)",
                "period": 60,
                "stat": "Maximum",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 7,
            "x": 18,
            "type": "metric",
            "properties": {
                "view": "timeSeries",
                "stacked": true,
                "metrics": [
                    [ "AWS/ES", "2xx", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}" ],
                    [ "AWS/ES", "3xx", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}" ],
                    [ "AWS/ES", "4xx", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}" ],
                    [ "AWS/ES", "5xx", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}" ]
                ],
                "region": "${var.region}",
                "title": "HTTP requests by response code (Count)",
                "period": 60,
                "stat": "Sum",
                "yAxis": {
                    "left": {
                        "showUnits": false
                    }
                }
            }
        },
        {
            "height": 1,
            "width": 24,
            "y": 0,
            "x": 0,
            "type": "text",
            "properties": {
                "markdown": "# ES Metrics"
            }
        },
        {
            "height": 1,
            "width": 24,
            "y": 19,
            "x": 0,
            "type": "text",
            "properties": {
                "markdown": "# Indexing Lambda"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 20,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Duration", "FunctionName", "taxon-indexing-lambda-${var.env}-index_taxons", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "title": "Duration",
                "stat": "Maximum",
                "period": 60
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 20,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "ConcurrentExecutions", "FunctionName", "taxon-indexing-lambda-${var.env}-index_taxons", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 26,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Errors", "FunctionName", "taxon-indexing-lambda-${var.env}-index_taxons", "Resource", "taxon-indexing-lambda-${var.env}-index_taxons", { "region": "${var.region}" } ],
                    [ ".", "Invocations", ".", ".", ".", ".", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 26,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Throttles", "FunctionName", "taxon-indexing-lambda-${var.env}-index_taxons", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 1,
            "width": 24,
            "y": 32,
            "x": 0,
            "type": "text",
            "properties": {
                "markdown": "# Concurrency Managing Lambda"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 33,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Duration", "FunctionName", "taxon-indexing-concurrency-manager-${var.env}", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 33,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "ConcurrentExecutions", "FunctionName", "taxon-indexing-concurrency-manager-${var.env}", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 39,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Errors", "FunctionName", "taxon-indexing-concurrency-manager-${var.env}", { "region": "${var.region}" } ],
                    [ ".", "Invocations", ".", ".", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 39,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Throttles", "FunctionName", "taxon-indexing-concurrency-manager-${var.env}", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 13,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/ES", "IndexingLatency", "DomainName", "idseq-${var.env}-elasticsearch", "ClientId", "${local.account_id}", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 1,
            "width": 24,
            "y": 45,
            "x": 0,
            "type": "text",
            "properties": {
                "markdown": "# Evict Expired Lambda"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 52,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Invocations", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_expired_taxons", "Resource", "taxon-indexing-eviction-lambda-${var.env}-evict_expired_taxons", { "label": "Invocations", "region": "${var.region}" } ],
                    [ ".", "Errors", ".", ".", ".", ".", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 46,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Duration", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_expired_taxons" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 46,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "ConcurrentExecutions", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_expired_taxons" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 52,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Throttles", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_expired_taxons", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 1,
            "width": 24,
            "y": 58,
            "x": 0,
            "type": "text",
            "properties": {
                "markdown": "# Selected Evictions Lambda"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 59,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Duration", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_selected_taxons" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 65,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Invocations", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_selected_taxons", { "region": "${var.region}" } ],
                    [ ".", "Errors", ".", ".", { "region": "${var.region}" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 59,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "ConcurrentExecutions", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_selected_taxons" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Maximum"
            }
        },
        {
            "height": 6,
            "width": 12,
            "y": 65,
            "x": 12,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Throttles", "FunctionName", "taxon-indexing-eviction-lambda-${var.env}-evict_selected_taxons" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Sum"
            }
        },
        {
            "type": "metric",
            "x": 6,
            "y": 13,
            "width": 6,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ES", "ClusterUsedSpace", "DomainName", "czid-${var.env}-heatmap-es", "ClientId", "${local.account_id}", { "id": "m1", "stat": "Maximum" } ],
                    [ ".", "FreeStorageSpace", ".", ".", ".", ".", { "id": "m2" } ]
                ],
                "view": "timeSeries",
                "stacked": true,
                "region": "${var.region}",
                "stat": "Sum",
                "period": 60
            }
        }
    ]
}
  EOF
}

resource "aws_sns_topic" "aws_heatmap_topic" {
  name = "${var.env}-idseq-heatmap-topic"
}

resource "aws_cloudwatch_metric_alarm" "czid-heatmap-es-low-storage" {
  alarm_name                = "${var.env}-czid-heatmap-es-low-storage"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 1
  metric_name               = "FreeStorageSpace"
  namespace                 = "AWS/ES"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "125000"
  alarm_description         = "OpenSearch Low Storage"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.aws_heatmap_topic.arn]
  actions_enabled           = true
  datapoints_to_alarm       = 1
  treat_missing_data        = "missing"
  dimensions = {
    DomainName = module.elasticsearch.elasticsearch_domain_name,
    ClientId   = local.account_id
  }
}

resource "aws_cloudwatch_metric_alarm" "czid-heatmap-es-cluster-status-yellow" {
  alarm_name                = "${var.env}-czid-heatmap-es-cluster-status-yellow"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  threshold                 = "0"
  alarm_description         = "OpenSearch Yellow Status"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.aws_heatmap_topic.arn]
  actions_enabled           = true
  datapoints_to_alarm       = 1
  treat_missing_data        = "missing"
  metric_query {
    id          = "metric_1"
    expression  = "metric_2 * 2 / 3"
    label       = "ClusterStatus State - Yellow"
    return_data = true
  }

  metric_query {
    id          = "metric_2"
    return_data = false
    metric {
      period      = "60"
      stat        = "Maximum"
      namespace   = "AWS/ES"
      metric_name = "ClusterStatus.yellow"
      dimensions = {
        DomainName = module.elasticsearch.elasticsearch_domain_name
        ClientId   = local.account_id
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "czid-heatmap-es-cluster-status-red" {
  alarm_name                = "${var.env}-czid-heatmap-es-cluster-status-red"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  threshold                 = "0"
  alarm_description         = "OpenSearch Red Status"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.aws_heatmap_topic.arn]
  actions_enabled           = true
  datapoints_to_alarm       = 1
  treat_missing_data        = "missing"
  metric_query {
    id          = "metric_1"
    expression  = "metric_2 * 2 / 3"
    label       = "ClusterStatus State - Red"
    return_data = true
  }

  metric_query {
    id          = "metric_2"
    return_data = false
    metric {
      period      = "60"
      stat        = "Maximum"
      namespace   = "AWS/ES"
      metric_name = "ClusterStatus.red"
      dimensions = {
        DomainName = module.elasticsearch.elasticsearch_domain_name
        ClientId   = local.account_id
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "czid-heatmap-ES-node-down" {
  alarm_name                = "${var.env}-czid-heatmap-ES-node-down"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = 2
  threshold                 = 2
  alarm_description         = "OpenSearch Node Down alarm"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.aws_heatmap_topic.arn]
  actions_enabled           = true
  datapoints_to_alarm       = 1
  treat_missing_data        = "missing"
  metric_query {
    id          = "m1"
    return_data = true
    metric {
      period      = "60"
      stat        = "Minimum"
      namespace   = "AWS/ES"
      metric_name = "Nodes"
      dimensions = {
        DomainName = module.elasticsearch.elasticsearch_domain_name
        ClientId   = local.account_id
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "czid-heatmap-es-slow-query" {
  alarm_name                = "${var.env}-czid-heatmap-es-slow-query"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "SearchLatency"
  namespace                 = "AWS/ES"
  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "5000"
  alarm_description         = "OpenSearch Slow Query"
  insufficient_data_actions = []
  alarm_actions             = [aws_sns_topic.aws_heatmap_topic.arn]
  actions_enabled           = true
  datapoints_to_alarm       = 1
  treat_missing_data        = "missing"
  dimensions = {
    DomainName = module.elasticsearch.elasticsearch_domain_name,
    ClientId   = local.account_id
  }
}