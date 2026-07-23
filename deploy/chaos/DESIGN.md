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
   be injected into a namespace carrying the **annotation**
   `chaos-mesh.org/inject=enabled`. (It is an ANNOTATION, not a label -- Chaos Mesh
   reads `ns.Annotations[chaos-mesh.org/inject]=="enabled"`, verified in
   `pkg/selector/generic/namespace/selector.go`; a label is silently ignored and the
   guardrail fails closed.) We annotate **only `seqtoid-dev`**, and only when an
   experiment window is authorized. `argocd`, `monitoring`, `kube-system`, the AWS LB
   controller, other tenants -- all physically un-targetable. Remove the annotation
   and every experiment no-ops. Proven 2026-07-22: with a label instead of the
   annotation, E1 fail-closed ("namespace is not enabled for chaos-mesh") and no pod
   was touched.

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
3. **Arm the target namespace:** annotate `seqtoid-dev` with
   `chaos-mesh.org/inject=enabled`
   (`kubectl annotate ns seqtoid-dev chaos-mesh.org/inject=enabled --overwrite`).
   ANNOTATION, not label. Until this annotation exists, every experiment is a
   no-op -- this is the master arm/disarm switch.
4. **Apply E1 only:** `kubectl apply -f deploy/chaos/experiments/e1-pod-kill.yaml`.
   Let it fire once overnight. Read the Workflow status + Grafana the next morning.
5. **Iterate:** if E1 holds clean, apply E2, then E3. Ticket every finding.
6. **AWS FIS (E4):** `terraform apply` the `chaos-fis.tf` template + role via CI
   (Rosetta wall -- no local apply), then run the FIS experiment manually the first
   time before scheduling it.
7. **Disarm:** remove the `chaos-mesh.org/inject=enabled` annotation
   (`kubectl annotate ns seqtoid-dev chaos-mesh.org/inject-`) for an instant global
   stop, and/or `kubectl delete -f deploy/chaos/experiments/` to stop scheduling.

Rollback is trivial: delete the inject annotation to disarm, delete the `_deliberate` app to
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

---

# EXPANSION -- toward "Netflix-grade, end-to-end" (platform-overhaul #794 follow-ups)

Everything below is **authored and held** in the same BUILT-NOT-DEPLOYED style: new
manifests are apply-on-purpose, nothing is armed until the checklist in section 13.
The four expansion themes are (1) complete the fault catalog, (2) automate the
hypothesis, (3) go continuous + CI-gated, (4) close the observability loop -- plus the
single biggest gap: (5) bring the **genomics pipeline** into scope safely.

## 8. Fault-catalog completion (E5-E8) -- AUTHORED

The E1-E4 baseline covered pod/network/stress/node. These four complete the Chaos
Mesh menu, each a `Schedule -> Workflow` with the same pre/in-flight StatusCheck
guardrails, staggered across the overnight window, `mode: one`, duration-bounded.

| # | File | Fault | Validates |
|---|------|-------|-----------|
| E5 | `experiments/e5-io.yaml` | `IOChaos` 100ms latency on `/tmp` | web tolerates a slow local disk. (The high-value disk case -- pipeline **scratch exhaustion**, the #799 NT/NR failure -- is a *pipeline-sandbox* experiment, section 9, not this one.) |
| E6 | `experiments/e6-dns.yaml` | `DNSChaos` resolution failure for `*.es.amazonaws.com` / `*.rds.amazonaws.com` | dependency DNS failure degrades cleanly + recovers, no crashloop (the OpenSearch-timeout / sandbox-NXDOMAIN class) |
| E7 | `experiments/e7-http-fit.yaml` | `HTTPChaos` abort 30% of outbound 443 calls | Netflix **FIT**: a partial dependency brownout is absorbed by retries/timeouts, not a user-facing storm |
| E8 | `experiments/e8-time.yaml` | `TimeChaos` -10m clock skew | JWT/TLS/date-versioning tolerate drift or fail cleanly |

Still to author (FIS-side, section 13 tickets): **AZ interruption** (Chaos Gorilla --
`aws:ec2:stop-instances` scoped to one AZ) and **Aurora RDS failover**
(`aws:rds:failover-db-cluster`) -- the managed-service faults Chaos Mesh cannot reach.

## 9. Pipeline chaos -- the disposable sandbox (the end-to-end gap)

The E-series targets the **web tier**. The genomics pipeline (S3 -> Step Functions ->
Batch -> OpenSearch) -- the actual product, and where our real incidents live (NT/NR
scratch exhaustion #799, spot interruptions) -- is deliberately **out of the web blast
radius** and needs its own, safe approach. The rule: **never fault the shared dev
pipeline in place; fault a disposable, isolated copy.**

**Redundancy without HA replicas.** The pipeline is Infrastructure-as-Code (SFN
definitions, Lambda code, Batch compute-envs/queues/job-defs in `cypherid-workflow-infra`
+ the swipe module). So "redundancy" for Lambda/SFN/Batch means: `terraform apply` an
independently-named **`-chaos` copy** (own queues, own S3 scratch prefix, own SSM path),
chaos-test *that*, and `terraform destroy` it. This extends the proven preview-sandbox
pattern (per-PR isolated web + DB schema + S3 prefix) to the pipeline tier.

**Four safety invariants make an unrecoverable break structurally impossible:**

1. **Isolated target.** Experiments run only against the `-chaos` pipeline copy; the
   shared dev pipeline is never selected.
2. **Fault transient runtime state, never durable IaC or data.** Kill an *execution*
   (a Batch job, a spot instance, an SFN task transition, a Lambda invocation) -- never
   the SFN definition / Lambda code / Batch env (IaC-recreatable) and never persistent
   data (S3 reference indexes, the taxon DB -- separately backed up; see the taxon
   rollback). Transient fault -> re-run; durable infra -> `terraform apply`; data ->
   backup/snapshot. All three recovery paths exist by construction.
3. **Synthetic inputs only.** Drive chaos with the benchmark sample runs (#388), never
   real user data.
4. **The hypothesis is the AUPR gate.** Success = the pipeline **retries/resumes and
   still produces AUPR >= 0.98** under fault. That single assertion proves end-to-end
   pipeline resilience -- and doubles as validation of the "resume from partial failure"
   behavior (one lane done, another failed) discussed for NT/NR.

**Pipeline experiments (to author under the sandbox -- section 13 tickets):** P1 Batch
job-kill mid-alignment (assert SFN retry); P2 spot-interrupt during a task (FIS, assert
tolerance the pipeline must already have); P3 **scratch-volume exhaustion** (reproduce
#799 on purpose, assert the split-volume fix holds); P4 S3 intermediate delay/`IOChaos`;
P5 SFN task-transition fault (assert Retry/Catch); P6 ECR pull throttle. Each gated on
the benchmark AUPR + a `terraform destroy`/re-apply recovery proof before enabling.

## 10. Automate the hypothesis (the ChAP leap) -- probe AUTHORED

Move the steady-state gate from "`/health_check`==200" to **metric-based canary
analysis**, so runs self-verify and abort inline -- no manual morning review.

- **SLO probe (AUTHORED, `slo-probe/slo-probe.yaml`).** A tiny read-only service that
  evaluates PromQL steady-state assertions (5xx rate, ALB target 5xx, p99 latency, web
  pods Ready) against the LGTM/Mimir stack and returns a single HTTP verdict
  (`/steady-state` -> 200 iff all hold, else 500 + which failed). Experiments point their
  pre-flight and continuous in-flight `StatusCheck` at this URL instead of
  `/health_check`. This is the automatic pass/fail + inline abort the program has been
  missing. (Extend the assertion set per experiment: E6/E7 add search-availability and
  heatmap-render SLOs; pipeline experiments add job-success-rate + queue-depth.)
- **Data-integrity assertion (to author).** After a fault clears, a Job runs a
  content check and fails the experiment on any drift -- reuse the taxon-lineage
  **CHECKSUM-fingerprint** idea (`taxonomy:fingerprint`) as the template. "No corruption"
  becomes a machine-checked post-condition, not an assumption.
- **Auto-ticket (to author).** On a failed hypothesis, a workflow step opens a Forgejo
  ticket (what fired, which SLO broke, links to the Grafana window) -- closing the #794
  loop exactly like the Sentry sweep.

## 11. Continuous + randomized + CI-gated (to author)

- **Randomized "chaos monkey."** A `Schedule -> Workflow` (`Task` templateType) that each
  night draws ONE fault at random from the E1-E8 catalog and applies it, so coverage
  compounds instead of testing the same four things. Same guardrails; the random pick is
  logged so a failure is reproducible.
- **CI-gated chaos (the "rock solid becomes structural" step).** A canonical fast fault
  set (pod-kill + a dependency brownout) run against a preview/ephemeral env as a
  **pre-promotion gate** in the deploy pipeline -- every release proves resilience before
  it ships, not just periodically overnight.

## 12. Close the observability loop (to author)

- **Grafana overlay + run annotations.** A workflow step posts a Grafana annotation
  (release-marker style) at fault start/stop, and a saved dashboard overlays the chaos
  window on App RED + ALB 5xx + Loki/Tempo -> one-click morning review (#797).
- **Templated experiment reports.** Auto-generate a per-run result doc (like the E1
  pod-kill result) from the Workflow status + the SLO-probe verdicts.
- **Sentry cross-check.** After a run, diff new Sentry issues in the window -> ties chaos
  into the triage loop.

## 13. Expanded un-hold / arm checklist

Steps 1-7 (section 5) still gate the web baseline. The expansion adds, each still
deliberate and reversible:

8.  **Deploy the SLO probe:** `kubectl apply -f deploy/chaos/slo-probe/slo-probe.yaml`
    (needs the LGTM/Mimir stack up). Verify `GET /steady-state` returns 200 on a healthy
    system, then repoint experiment `StatusCheck` URLs from `/health_check` to the probe.
9.  **Apply E5-E8** one at a time, morning-after review, ticket findings (as E1-E3).
10. **FIS AZ + RDS-failover** templates (`terraform apply` via CI), run attended first.
11. **Stand up the pipeline `-chaos` sandbox** (its own `terraform` workspace/prefix),
    prove `destroy`+re-apply recovery, then apply pipeline experiments P1-P6 gated on the
    benchmark AUPR. **Never** point a pipeline experiment at the shared dev pipeline.
12. **Randomized monkey + CI-gate + Grafana overlay/auto-ticket** last, once the fixed
    experiments are trusted.
13. **Flip the switch:** arming remains the single `chaos-mesh.org/inject=enabled` annotation
    (web) + applying the pipeline-sandbox experiments (pipeline). Disarm = remove the
    label + `terraform destroy` the sandbox. Prod chaos stays OUT of scope until dev proves
    the whole loop and a separate prod decision is made (canary + business-metric abort).
