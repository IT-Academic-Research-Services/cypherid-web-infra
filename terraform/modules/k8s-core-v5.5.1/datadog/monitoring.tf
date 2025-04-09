locals {
  prom_query_tags    = "cluster_name:${var.eks_cluster_id}"
  ingress_query_tags = "ingress.k8s.aws/cluster:${var.eks_cluster_id}"
  opsgenie_tags = [
    var.tags.env,
    var.tags.service,
    var.eks_cluster_id,
  ]

  alerts = {
    dns_registry_errors = {
      monitor_name = "External DNS Registry Errors"
      service      = var.monitor_app_names.external_dns
      query        = "sum(last_10m):${var.monitor_app_names.external_dns}.registry_errors_total{${local.prom_query_tags}} > 6"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes-external-dns"
      thresholds = {
        critical          = 6.0
        critical_recovery = 5.0
        warning           = 4.0
        warning_recovery  = 0.01
      }
    }
    dns_source_errors = {
      monitor_name = "External DNS Source Errors"
      service      = var.monitor_app_names.external_dns
      query        = "sum(last_5m):${var.monitor_app_names.external_dns}.source_errors_total{${local.prom_query_tags}} > 3"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes-external-dns"
      thresholds = {
        critical          = 3.0
        critical_recovery = 2.0
        warning           = 1.0
        warning_recovery  = 0.01
      }
    }
    ingress_errors = {
      monitor_name = "AWS ALB Ingress Controller errors"
      service      = var.monitor_app_names.alb_ingress
      query        = "sum(last_5m):${var.monitor_app_names.alb_ingress}.errors{${local.prom_query_tags}} > 6"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes-alb-ingress"
      thresholds = {
        critical          = 6.0
        critical_recovery = 5.0
        warning           = 1.0
        warning_recovery  = 0.01
      }
    }
    ingress_errors_rate = {
      monitor_name = "AWS ALB Ingress Controller error rate"
      service      = var.monitor_app_names.alb_ingress
      query        = "sum(last_5m):sum:${var.monitor_app_names.alb_ingress}.errors{${local.prom_query_tags}}.as_count().rollup(min, 300) / ( sum:${var.monitor_app_names.alb_ingress}.errors{${local.prom_query_tags}}.as_count().rollup(min, 300) + sum:${var.monitor_app_names.alb_ingress}.successes{${local.prom_query_tags}}.as_count() ) > 0.35"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes-alb-ingress"
      thresholds = {
        critical          = 0.35
        critical_recovery = 0.2
        warning           = 0.1
        warning_recovery  = 0.01
      }
    }
    ingress_api_error_rate = {
      monitor_name = "AWS ALB Ingress Controller AWS API error rate"
      service      = var.monitor_app_names.alb_ingress
      query        = "sum(last_5m):max:${var.monitor_app_names.alb_ingress}.api_errors{${local.prom_query_tags}} / max:${var.monitor_app_names.alb_ingress}.api_requests{${local.prom_query_tags}} > 0.05"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes-alb-ingress"
      thresholds = {
        critical          = 0.05
        critical_recovery = 0.01
        warning           = 0.01
        warning_recovery  = 0.001
      }
    }
    fluentbit_errors = {
      monitor_name = "Fluent Bit Errors"
      service      = var.monitor_app_names.fluentbit
      query        = "sum(last_5m):max:fluentbit.output.errors{${local.prom_query_tags}} by {host}.as_count() / max:fluentbit.output.proc_records{${local.prom_query_tags}} by {host}.as_count() > 0.05"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes-fluent-bit"
      thresholds = {
        critical          = 0.05
        critical_recovery = 0.01
        warning           = 0.01
        warning_recovery  = 0.001
      }
    }
    k8s_core_daemonset_not_ready = {
      monitor_name = "k8s-core Daemonset Scheduled But Not Ready"
      service      = "k8s-core-daemonset"
      query        = "min(last_15m):max:kubernetes_state.daemonset.scheduled{${local.prom_query_tags},namespace:k8s-core} by {daemonset} - max:kubernetes_state.daemonset.ready{${local.prom_query_tags},namespace:k8s-core} by {daemonset} > 1"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      thresholds = {
        critical          = 1
        critical_recovery = 0.01
        warning           = null
        warning_recovery  = null
      }
    }
    kube_system_daemonset_not_ready = {
      monitor_name = "kube-system Daemonset Scheduled But Not Ready"
      service      = "kube-system-daemonset"
      query        = "min(last_15m):max:kubernetes_state.daemonset.scheduled{${local.prom_query_tags},namespace:kube-system} by {daemonset} - max:kubernetes_state.daemonset.ready{${local.prom_query_tags},namespace:kube-system} by {daemonset} > 1"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      thresholds = {
        critical          = 1
        critical_recovery = 0.01
        warning           = null
        warning_recovery  = null
      }
    }
    k8s_core_deployment_not_ready = {
      monitor_name = "k8s-core Deployment Not Available"
      service      = "k8s-core-deployment"
      query        = "min(last_5m):max:kubernetes_state.deployment.replicas_desired{${local.prom_query_tags},namespace:k8s-core} by {deployment} - max:kubernetes_state.deployment.replicas_available{${local.prom_query_tags},namespace:k8s-core} by {deployment} >= 1"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      thresholds = {
        critical          = 1
        critical_recovery = 0.01
        warning           = null
        warning_recovery  = null
      }
    }
    kube_system_deployment_not_ready = {
      monitor_name = "kube-system Deployment Not Available"
      service      = "kube-system-deployment"
      query        = "min(last_5m):max:kubernetes_state.deployment.replicas_desired{${local.prom_query_tags},namespace:kube-system} by {deployment} - max:kubernetes_state.deployment.replicas_available{${local.prom_query_tags},namespace:kube-system} by {deployment} >= 1"
      full_window  = false
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      thresholds = {
        critical          = 1
        critical_recovery = 0.01
        warning           = null
        warning_recovery  = null
      }
    }
    pods_pending_alarm = {
      monitor_name = "Pods stuck in pending state"
      service      = "global"
      query        = "min(last_1h):max:kubernetes_state.pod.ready{pod_phase:pending,${local.prom_query_tags}} by {pod_name,cluster_name} >= 2"
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      full_window  = true
      thresholds = {
        critical          = 2
        critical_recovery = 1
        warning           = null
        warning_recovery  = null
      }
    }
    pods_failed_alarm = {
      monitor_name = "Pods failed"
      service      = "global"
      query        = "min(last_1h):max:kubernetes_state.pod.ready{pod_phase:failed,${local.prom_query_tags}} by {pod_name,cluster_name} >= 1"
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      full_window  = true
      thresholds = {
        critical          = 1
        critical_recovery = 0.5
        warning           = null
        warning_recovery  = null
      }
    }
    alb_target_out_of_sync = {
      monitor_name = "ALB Target group out of sync"
      service      = "global"
      query        = "min(last_1h):abs( avg:aws.autoscaling.group_total_instances{${local.prom_query_tags}} - avg:aws.applicationelb.healthy_host_count{${local.ingress_query_tags}} ) > 2"
      runbook      = "https://czi.atlassian.net/wiki/spaces/SI/pages/1786743552/InfraEng%2BKubernetes#InfraEng|Kubernetes"
      full_window  = true
      thresholds = {
        critical          = 2
        critical_recovery = 1.5
        warning           = 1.5
        warning_recovery  = 1
      }
    }
  }
}

# module "monitored_service" {
#   source              = "../../monitored_service"
#   dd_service          = "${var.eks_cluster_id} K8s Core"
#   opsgenie_dd_service = "${var.eks_cluster_id} K8s Core"
#   alerts              = local.alerts
#   mute_dd_alerts      = var.mute_dd_alerts
#   opsgenie_tags       = local.opsgenie_tags

#   ops_genie_owner_team = var.ops_genie_owner_team

#   env     = var.tags.env
#   project = var.tags.project
#   service = var.tags.service
# }
