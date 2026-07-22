# Chaos engineering on dev -- design (platform-overhaul #794)

Deliberate, blast-radius-scoped, overnight-only resilience testing for the dev
platform. This is the "Netflix Chaos Monkey" idea translated to our stack: we run
Argo/EKS, not Spinnaker, so Chaos Monkey-the-product is not a drop-in. The
discipline is, via two k8s/AWS-native tools that together cover more than the
original Simian Army.

**Status: BUILT, NOT DEPLOYED.** Everything here is authored and reviewable but
nothing runs until it is deliberately applied (see "What deploying takes"). The
install lives in `_deliberate/` (applied by hand, never by a root app) and the
experiments are plain manifests that must be `kubectl apply`-ed on purpose.

Scope: **dev only**, per the standing envelope. Staging/prod are out of scope
until dev proves the guardrails.

---

## 1. Why this exists

We have been finding resilience bugs by hand and by accident:

- both dev web pods landed on **one node** (SPOF) -- found by eyeballing
  `kubectl get pods -o wide`, fixed with PDB + topology spread (#146).
- the blueGreen cutover dropped traffic for ~30s every deploy -- found by a
  curl-loop, fixed with pingpong + readiness gates (#782).
- Redis `EALREADY` on worker connect (#790), OpenSearch connect-timeouts on node
  rotation (taxon-indexing "N/0"), kubelet eviction storms under memory pressure.

Every one of those is a **non-obvious failure that a chaos experiment surfaces on
a schedule instead of by luck.** The goal is to institutionalize that: inject a
controlled fault overnight, assert the platform holds its steady state, and turn
anything that does not hold into a ticket -- the same loop as the Sentry sweep,
but for resilience instead of exceptions.

## 2. Tooling -- capability parity with Netflix

Netflix's famous Chaos Monkey only killed instances. The full Simian Army spread
capability across many "monkeys." We consolidate that into two tools:

| Layer | Tool | Covers |
|-------|------|--------|
| App / pod / network / dependency | **Chaos Mesh** (CNCF operator on our EKS) | pod-kill / pod-failure / container-kill; network delay / loss / corrupt / **partition** (simulate Redis/OpenSearch/DB/S3 down without touching the managed service); CPU/mem **stress**; IO faults; DNS failure; **HTTP fault injection**; clock skew; EC2 stop/restart + EBS detach (AWSChaos) |
| Infra / managed-service | **AWS FIS** (managed) | real EC2/node termination; AZ power interruption; RDS reboot/failover; API throttling -- the control-plane failures Chaos Mesh cannot reach into |

**Coverage vs the Simian Army:**

| Netflix "monkey" | Our equivalent |
|------------------|----------------|
| Chaos Monkey (kill instances) | Chaos Mesh `PodChaos` pod-kill + AWS FIS terminate-instances |
| Latency Monkey | Chaos Mesh `NetworkChaos` delay/loss |
| Chaos Kong (kill a region/AZ) | AWS FIS `aws:ec2:stop-instances` scoped to an AZ |
| Conformity/Security/Janitor Monkey | NOT chaos fault-injection -- policy/hygiene, handled elsewhere (OPA/Gatekeeper, the sandbox reaper) |

Net: **Chaos Mesh + AWS FIS >= the Simian Army**, k8s-native and GitOps-friendly.

**Chaos Mesh vs LitmusChaos (the one real choice):** both are CNCF. Chaos Mesh
has the broader fault menu and (via `Workflow` + `StatusCheck`) can pre-flight and
in-flight abort. LitmusChaos's differentiator is first-class **probes** (http/cmd/
prometheus) that validate a steady-state hypothesis and abort inline. Chaos Mesh's
`StatusCheck` gets us the same abort behavior for HTTP steady-state, and we already
run Grafana/LGTM for the deeper signal, so **the design picks Chaos Mesh.** If we
later want richer hypothesis probes than HTTP, Litmus is the swap -- the experiment
catalog below ports directly.

## 3. Guardrails -- how chaos cannot escape dev or daytime

Four independent controls, each sufficient on its own:

1. **Namespace filtering (physical).** Chaos Mesh installs with
   `controllerManager.enableFilterNamespace: true`. With that on, chaos can ONLY
   be injected into a namespace carrying the label
   `chaos-mesh.org/inject=enabled`. We label **only `seqtoid-dev`**, and only when
   an experiment window is authorized. `argocd`, `monitoring`, `kube-system`, the
   AWS LB controller, other tenants -- all physically un-targetable. Remove the
   label and every experiment no-ops.

2. **Overnight-only schedule.** Every experiment is wrapped in a Chaos Mesh
   `Schedule` (cron, **UTC**) firing in a 2-6am America/New_York window
   (`0 6-10 * * *` UTC) with `concurrencyPolicy: Forbid`. Daytime dev users (the
   team + ikrama's testing) are never in the blast radius. AWS FIS schedules the
   same way via EventBridge.

3. **Steady-state gate (fail-safe).** Each experiment is a `Workflow`, not a bare
   fault. A `StatusCheck` runs FIRST (is dev already healthy? if not, ABORT -- never
   inject chaos into an already-broken system) and CONTINUOUSLY during the fault
   (if `/health_check` fails past the tolerated window, the workflow aborts and the
   fault is removed early). This is the "do not break anything anyone needs"
   control: the experiment stops itself the moment steady state breaks.

4. **Bounded blast + auto-heal.** Every fault has `mode: one` (a single pod, not
   all), a hard `duration`, and Chaos Mesh's own recovery removes the fault when
   the experiment ends or is deleted. `dev` is a non-prod env to begin with, so
   this is defense in depth on top of "it is already dev."

## 4. Experiment catalog (staged)

Run in order; each is a `Schedule` -> `Workflow` in `deploy/chaos/experiments/`.
Ship them one at a time, review the morning after, ticket findings.

| # | File | Fault | Validates | Guardrail highlights |
|---|------|-------|-----------|----------------------|
| E1 | `e1-pod-kill.yaml` | `PodChaos` pod-kill, one web pod | PDB `maxUnavailable:1` + topology spread + pingpong survive a pod loss with zero user-facing 503 | pre/in-flight StatusCheck on `/health_check`; `mode: one` |
| E2 | `e2-network-dependency.yaml` | `NetworkChaos` delay+partition to OpenSearch/Redis endpoints | graceful degradation when a dependency is slow/down (does the app 500, hang, or degrade cleanly?) -- directly probes the #790 Redis + OpenSearch-timeout classes | 60s duration; targets external endpoints only; StatusCheck |
| E3 | `e3-stress.yaml` | `StressChaos` CPU+mem on one web pod | limits/requests are right, no cascade eviction (the #709 memory-pressure history) | `mode: one`; 120s; StatusCheck |
| E4 | AWS FIS (`terraform/.../chaos-fis.tf`) | terminate one web node | Karpenter re-provisions, PDB holds, pods reschedule onto a surviving node | FIS stop-condition wired to a CloudWatch alarm; tag-scoped to the web NodePool |

Future (not authored yet): AZ interruption (FIS), RDS failover (FIS),
`HTTPChaos` on the GraphQL path, `DNSChaos`.

## 5. What deploying takes (the un-hold checklist)

Nothing below has run. To go live, deliberately and in order:

1. **Greenlight the blast radius** (Tom) -- confirm dev-only, overnight window,
   E1-first.
2. **Install Chaos Mesh:** `kubectl apply -f deploy/argocd/_deliberate/chaos-mesh.yaml`
   (creates the Argo Application; it syncs the operator into the `chaos-mesh` ns).
   Verify `enableFilterNamespace` is on and the dashboard is up (behind the Grafana
   ingress auth pattern, not public).
3. **Arm the target namespace:** label `seqtoid-dev` with
   `chaos-mesh.org/inject=enabled`. Until this label exists, every experiment is a
   no-op -- this is the master arm/disarm switch.
4. **Apply E1 only:** `kubectl apply -f deploy/chaos/experiments/e1-pod-kill.yaml`.
   Let it fire once overnight. Read the Workflow status + Grafana the next morning.
5. **Iterate:** if E1 holds clean, apply E2, then E3. Ticket every finding.
6. **AWS FIS (E4):** `terraform apply` the `chaos-fis.tf` template + role via CI
   (Rosetta wall -- no local apply), then run the FIS experiment manually the first
   time before scheduling it.
7. **Disarm:** remove the `chaos-mesh.org/inject=enabled` label (instant global
   stop) and/or `kubectl delete -f deploy/chaos/experiments/` to stop scheduling.

Rollback is trivial: delete the label to disarm, delete the `_deliberate` app to
remove the operator. No app code, no chart, no CD pipeline touched.

## 6. Steady-state definition (the hypothesis)

For every experiment the asserted steady state is: **`https://dev.seqtoid.org/health_check`
returns 200 throughout, and returns to 200 within the recovery window after the
fault clears.** E2 additionally asserts the app degrades cleanly (no 5xx storm)
while the dependency is impaired. Deeper hypotheses (authed page renders, a sample
run completes) are a follow-up once the HTTP baseline is trusted.

## 7. Observability

Experiments are correlated with the existing LGTM stack: Grafana (App RED
dashboard, ALB 5xx CloudWatch panel), Loki (app logs during the fault), Tempo
(traces showing where latency/errors propagate). The morning-after review is
"overlay the experiment window on those dashboards." Alertmanager DELIVERY stays
off until the SMTP secret exists (#700), so review is pull, not push, for now.
