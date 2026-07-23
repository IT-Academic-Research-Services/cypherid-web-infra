# Seqtoid Dev - Grafana Dashboards

DEV-only observability for the seqtoid platform and the Chaos Engine. Dashboards are
provisioned into Grafana (kube-prometheus-stack, `monitoring` namespace) through the
dashboard sidecar, which watches ConfigMaps labelled `grafana_dashboard: "1"` and loads
each `*.json` data key. To add or change a dashboard, edit the JSON, regenerate the
ConfigMap YAML, and `kubectl apply` it; the sidecar hot-reloads within seconds.

## Files

| File | Purpose |
| --- | --- |
| `seqtoid-dev-platform.json` | Dashboard model (edit this) |
| `seqtoid-dev-chaos.json` | Dashboard model (edit this) |
| `grafana-dashboard-seqtoid-dev-platform.yaml` | ConfigMap wrapping the platform JSON |
| `grafana-dashboard-seqtoid-dev-chaos.yaml` | ConfigMap wrapping the chaos JSON |

Regenerate the ConfigMap from the JSON (indent the JSON 4 spaces under a `<name>.json: |`
block key, namespace `monitoring`, label `grafana_dashboard: "1"`). Apply with:

```
export AWS_PROFILE=idseq-dev   # kubeconfig SSO profile for czid-dev-eks-v2
kubectl apply -f deploy/observability/grafana-dashboard-seqtoid-dev-platform.yaml
kubectl apply -f deploy/observability/grafana-dashboard-seqtoid-dev-chaos.yaml
```

Datasources (already wired in the cluster, referenced by uid): `prometheus` (default,
kube-prometheus-stack), `cloudwatch` (IRSA), `loki`, `tempo`, `alertmanager`.

## Dashboard: Seqtoid Dev - Platform Overview (`uid: seqtoid-dev-platform`)

"See everything" view of the dev workload. Every panel query was verified against live
dev Prometheus / CloudWatch before shipping (no speculative "No data" panels).

Template variables: `region` (us-west-2), `alb` (the dev web ALB dimension value; change
this if the ALB is recreated - see the CloudWatch note below).

Rows and panels:

- **Workload health (kube-state-metrics)**
  - Pods ready (stat): `sum(kube_pod_status_ready{namespace="seqtoid-dev",condition="true"})`
  - Rollout available replicas (stat): `rollout_info_replicas_available{exported_namespace="seqtoid-dev",name="czid-dev-seqtoid-web"}`
  - Pod ready state by pod: `kube_pod_status_ready{namespace="seqtoid-dev",condition="true"}`
  - Container restarts total by pod: `kube_pod_container_status_restarts_total{namespace="seqtoid-dev"}`
  - Restart rate (15m): `sum(rate(kube_pod_container_status_restarts_total{namespace="seqtoid-dev"}[15m])) by (pod)`
  - Pods by phase: `sum(kube_pod_status_phase{namespace="seqtoid-dev"}) by (phase)`
- **Argo Rollout (czid-dev-seqtoid-web)** - the dev web workload is an Argo Rollout, not a
  Deployment, so it is absent from `kube_deployment_*`. Rollout metrics come from the
  argo-rollouts controller (`namespace=argo-rollouts`), keyed by `exported_namespace` and `name`.
  - Rollout replicas: `rollout_info_replicas_{available,desired,updated,unavailable}{exported_namespace="seqtoid-dev",name="czid-dev-seqtoid-web"}`
  - Rollout phase (active == 1): `rollout_phase{exported_namespace="seqtoid-dev",name="czid-dev-seqtoid-web"}`
- **Resource usage (cAdvisor)** - grouped by pod (each dev workload runs a single replica
  except the web rollout at 2, so per-pod is effectively per-workload):
  - CPU cores by pod: `sum(rate(container_cpu_usage_seconds_total{namespace="seqtoid-dev",container!=""}[5m])) by (pod)`
  - Memory working set by pod: `sum(container_memory_working_set_bytes{namespace="seqtoid-dev",container!=""}) by (pod)`
- **Node health (node-exporter)**
  - Node CPU %: `100 * (1 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])))`
  - Node memory used %: `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)`
  - Node root disk used %: `100 * (1 - node_filesystem_avail_bytes{mountpoint="/",fstype!~"tmpfs|overlay|squashfs"} / node_filesystem_size_bytes{...})`
- **Dev web ALB (CloudWatch AWS/ApplicationELB)** - datasource `cloudwatch`, dimension
  `LoadBalancer=$alb`, `matchExact: true`:
  - Request count (Sum), Target response time p50/p90/p99 (extended stats),
    5xx target + ELB (Sum), Healthy/unhealthy hosts (Average).

### CloudWatch ALB dimension

The dev web ALB LoadBalancer dimension is:

```
app/k8s-seqtoidd-cziddevs-c4552c1c21/f5632d3be5837a88
```

Confirmed via `aws cloudwatch list-metrics --namespace AWS/ApplicationELB`. The
`k8s-seqtoidd-cziddevs-*` prefix is the dev web ALB; `k8s-seqtoidp-*` are the per-PR
preview sandboxes and `k8s-grafanadev-*` is Grafana's own ALB. Panels pin the exact value
via the `$alb` template variable with `matchExact: true` so they never glob in sandbox
traffic. If the ALB is recreated (new random suffix), update the `$alb` variable default.

## Dashboard: Seqtoid Dev - Chaos Engine (`uid: seqtoid-dev-chaos`)

Built for watching a chaos experiment land and the platform recover. Default time range
`now-1h`, refresh 30s.

- **Chaos Mesh operator health (chaos-mesh ns)** - kube-state-metrics for the operator:
  - Pods ready (stat): `sum(kube_pod_status_ready{namespace="chaos-mesh",condition="true"})`
  - Pods NOT ready (stat): `count(kube_pod_status_ready{namespace="chaos-mesh",condition="true"} == 0)`
  - Pod ready by pod, restarts by pod, pods by phase (same metric families, `namespace="chaos-mesh"`).
- **Blast radius on seqtoid-dev** - the impact view. Same ready/restart/CPU/memory
  families as the platform dashboard but framed as fault impact, plus rollout
  available-vs-desired replicas to show recovery. Run an experiment from
  `deploy/chaos/experiments/` (e.g. `e1-pod-kill`, `e3-stress`) and watch pods leave
  ready, restart, or spike here, then recover.

### Fault-window annotation overlay

The dashboard defines a Grafana annotation layer **Chaos fault window** (tag `chaos`). To
overlay the exact experiment window on every panel, create a region annotation tagged
`chaos` (manually via the panel, or have the chaos runner POST to
`POST /api/annotations` with `"tags":["chaos"]`, `timeStart`/`timeEnd`). This is the
"template row where fault-window annotations will overlay" from the spec - the layer is
pre-wired; only the annotation source (manual or runner-driven) remains to be chosen.

## Deferred / follow-ups (honest scope)

These were intentionally NOT built as live panels because their data does not exist on dev
yet. Building them now would render "No data", which this work explicitly avoids.

1. **App-level HTTP 5xx rate and request latency (Rails).** The Rails app does not export
   HTTP request metrics to Prometheus. RED-style app metrics currently live only in
   OTel/Tempo (traces) and Loki (logs); ALB-observed 5xx/latency are on the CloudWatch
   panels above (edge view, not per-endpoint). **Follow-up:** add a Rails Prometheus
   exporter (e.g. `prometheus_client` + `yabeda-rails`/`yabeda-puma` middleware exposing
   `/metrics`) and a ServiceMonitor scraping the web rollout, then add
   `http_requests_total` rate-by-status and `http_request_duration_seconds` histogram
   panels (per-endpoint p50/p90/p99, 5xx rate). Until then the ALB CloudWatch panels are
   the app-latency/5xx proxy.

2. **Chaos SLO-probe steady-state graph.** The SLO probe at `chaos-slo-probe.chaos-mesh`
   (Service :80 -> pod :8080) is an **on-demand HTTP verdict endpoint**: `GET /steady-state`
   returns JSON like `{"steady_state": true, "failed": []}`, evaluated against the
   in-cluster kube-prometheus-stack. It is **not** a Prometheus `/metrics` endpoint, so it
   is not scraped and cannot be graphed as a timeseries as-is. A ServiceMonitor alone would
   not help (nothing to parse). **Follow-up:** have the probe additionally expose a
   Prometheus-format `/metrics` endpoint publishing a `chaos_slo_steady_state` gauge (and
   per-assertion gauges), add a ServiceMonitor for the `chaos-slo-probe` Service, then add a
   steady-state timeline panel to the Chaos Engine dashboard.

3. **Chaos Mesh experiment metrics (`chaos_*`).** The chaos-controller-manager does not
   currently serve scrapeable Prometheus metrics on dev (metrics port returned connection
   refused; no `chaos_*` series exist in Prometheus, no ServiceMonitor). Experiment
   health is therefore shown indirectly via chaos-mesh pod health + the blast-radius panels.
   **Follow-up:** once the controller-manager metrics endpoint is confirmed serving, add a
   ServiceMonitor for `chaos-mesh-controller-manager` and add experiment-count / reconcile
   panels.

## Environment note

DEV-only. Cluster `arn:aws:eks:us-west-2:491013321714:cluster/czid-dev-eks-v2`; always
`export AWS_PROFILE=idseq-dev` before kubectl/aws. Do not port these ConfigMaps to
staging/prod without separate review.
