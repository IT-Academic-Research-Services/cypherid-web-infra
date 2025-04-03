locals {
  fullname = "datadog-agent-cluster-agent"
  values   = <<EOF
registry: public.ecr.aws/datadog
datadog:
  apiKey: ${var.api_key}
  clusterName: ${var.eks_cluster_id}
  kubeStateMetricsEnabled: false
  leaderElection: true
  dogstatsd:
    originDetection: true
    nonLocalTraffic: true
  apm:
    enabled: false
  collectEvents: true
  env:
  - name: DD_KUBELET_TLS_VERIFY
    value: "false"
  # DD_CHECK_RUNNERS tells the agent how many parallel goroutines to use to run checks.
  # Setting DD_CHECK_RUNNERS to 0 will instruct the agents to identify and set
  # the optimal number of runners based on the collector queue.
  - name: DD_CHECK_RUNNERS
    value: "0"
  clusterChecks:
    enabled: true
agents:
  useConfigMap: true
  customAgentConfig:
    ${indent(4, file("${path.module}/datadog.yaml"))}
  image:
    tag: ${var.agent_tag}
    pullPolicy: Always
  containers:
    agent:
      resources:
        requests:
          memory: 512Mi
          cpu: 200m
        limits:
          memory: 512Mi
          cpu: 500m
      # Use existing agent pods to run cluster checks instead of running separate cluster check pods
      # (as would happen with clusterChecks.enabled = true)
      # Manually set variables described in https://docs.datadoghq.com/agent/cluster_agent/clusterchecks/
      env:
        - name: DD_CLC_RUNNER_ENABLED
          value: "true"
        - name: DD_CLC_RUNNER_HOST
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: DD_CRI_SOCKET_PATH
          value: /var/run/containerd/containerd.sock
  priorityClassName: ${var.priority_class}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                  - linux
              - key: kubernetes.io/arch
                operator: In
                values:
                  - amd64
                  - arm64
              - key: eks.amazonaws.com/compute-type
                operator: NotIn
                values:
                  - fargate
  tolerations:
    - operator: Exists
  # Override the kubernetes_state.d autodiscovery configs, to prevent double counting
  # kube-state-metrics metrics since we manually configure the check in kube_state_metrics.tf
  # See https://docs.datadoghq.com/agent/faq/kubernetes-state-cluster-check/ for details.
  volumeMounts:
  - name: empty-dir
    mountPath: /etc/datadog-agent/conf.d/kubernetes_state.d
  - name: containerdsocket
    mountPath: /var/run/containerd/containerd.sock
  volumes:
  - name: empty-dir
    emptyDir: {}
  - hostPath:
      path: /var/run/containerd/containerd.sock
    name: containerdsocket
# Need cluster agent running to collect cluster checks
clusterAgent:
  enabled: true
  image:
    tag: ${var.agent_tag}
    pullPolicy: Always
  env:
  - name: DD_CLUSTER_CHECKS_ADVANCED_DISPATCHING_ENABLED
    value: "true"
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 512Mi
localService:
  forceLocalServiceEnabled: true
EOF
}

resource "helm_release" "datadog-agent" {
  name       = "datadog-agent"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "3.38.3"
  namespace  = var.namespace
  values     = [local.values]

  # datadog-agent can take a long time to rotate out all the nodes due to rate
  # limiting it has set up. Using a 20 minute timeout instead of 5 minute default.
  timeout = 1200
}
