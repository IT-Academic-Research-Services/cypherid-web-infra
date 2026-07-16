# `_deliberate/` — applied by hand, NEVER by a root app

These Argo `Application` manifests are intentionally **outside every root app's
path**. Each has a rollout that must be driven deliberately, so auto-sync is wrong.

## Contents

| File | Why it's deliberate |
|------|---------------------|
| `sigstore-policy-controller.yaml` + `sigstore-cosign-policy.yaml` | Cosign admission gate (#77). Installs a cluster-wide admission webhook. Follows a staged **warn → observe → enforce** rollout (see the PR that added it, #148). Auto-syncing it would skip the observation gate. Apply per its documented steps; it comes up in `mode: warn` with `failurePolicy: Ignore`. |
| `seqtoid-node-backend-dev.yaml` | The Node/NestJS backend strangler. Not yet deployed on dev. Apply deliberately when that slice is ready — not as a side effect of standing up the dev root. |
| `kube-prometheus-stack.yaml` | Observability Phase 1 (#608/#426): Prometheus + Alertmanager + Grafana + cluster metrics. Installs large prometheus-operator CRDs (ServerSideApply) and a cluster-wide monitoring stack, so it is applied and observed deliberately. Needs the `grafana-admin` secret first (below). Phase 2 layers Tempo/Loki as Grafana datasources; Phase 3 points the in-cluster OTel collector at it. |
| `tempo.yaml` | Observability Phase 2a: Grafana Tempo (traces backend), single-binary + local gp2 storage, OTLP receiver. The OTel collector (Phase 3) exports spans here. |
| `loki.yaml` | Observability Phase 2b: Grafana Loki (logs backend), SingleBinary + filesystem gp2 storage. The OTel collector exports app logs here; pod-log shipping is Phase 5. |
| `grafana-lgtm-datasources.yaml` | Observability Phase 2: sidecar-loaded ConfigMap adding the Tempo + Loki Grafana datasources. A raw resource (not an Application) so provisioning stays decoupled from the kps chart sync. |

## To apply one (deliberately)

```
kubectl apply -f deploy/argocd/_deliberate/<app>.yaml      # creates the Application
# then sync + observe in the Argo UI / CLI per that app's rollout notes
```

## kube-prometheus-stack apply steps

```
# 1. Grafana admin creds (NOT in git) -- create before applying the app:
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"   # capture it in the password manager

# 2. Create the Application + let Argo sync it:
kubectl apply -f deploy/argocd/_deliberate/kube-prometheus-stack.yaml
argocd app sync kube-prometheus-stack   # or the Argo UI

# 3. Verify + reach the frontend (no ingress yet -- port-forward):
kubectl -n monitoring get pods            # prometheus / alertmanager / grafana / kube-state-metrics Running
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
#   -> http://localhost:3000 (admin / the generated password)
```

## Alerting email delivery (#608) -- needs the UCSF SMTP password (Tom)

The chart already ships every node/pod alert (KubeNodeNotReady, KubeNodeUnreachable, KubePodNotReady,
etc.) and Alertmanager is now configured to email `Thomas.Horvath@ucsf.edu` via the UCSF Office365
mailbox `SeqtoID-Support@ucsf.edu`. Argo CD Notifications (deploy/sync failures) is already wired to the
same mailbox. Both just need the SMTP password secret (a credential -- Tom creates it, not in git):

```
# 1. Alertmanager SMTP password (key MUST be 'password'):
kubectl -n monitoring create secret generic alertmanager-smtp \
  --from-literal=password='<Office365 app password for SeqtoID-Support@ucsf.edu>'

# 2. Argo CD Notifications SMTP creds (referenced by argocd-notifications-cm as $email-username/$email-password):
kubectl -n argocd create secret generic argocd-notifications-secret \
  --from-literal=email-username='SeqtoID-Support@ucsf.edu' \
  --from-literal=email-password='<same Office365 app password>'
```

Until then, alerts still FIRE and are visible in Alertmanager/Grafana (port-forward) -- they just do not
email. Verify after creating the secret: `kubectl -n monitoring logs sts/alertmanager-kube-prometheus-stack-alertmanager`
shows no SMTP auth errors, and a test alert (or the current node alerts) arrives by email.

Do not `git mv` these into `../apps/<env>/` unless you intend them to become
root-managed and auto-synced.
