# Sandbox pipeline-chaos (P-series) — setup runbook

Adapts the P1–P6 pipeline chaos (`../README.md`, built for the dev-chaos copy in the dev account) to the
**sandbox account (941377154785)**, faulting a disposable **`idseq-swipe-sandbox-chaos-*`** pipeline copy —
never the `idseq-swipe-sandbox-*` pipeline used for the e2e proof.

**Status: BUILT, NOT APPLIED / NOT ARMED.** No parallel pipeline stood up, no `terraform apply`, no
`kubectl apply`, no FIS start. Arming is deliberate and staged (below). This is intentional — especially
after the 2026-07-26 nodegroup incident, nothing here runs until reviewed.

## The disposable copy = a variable flip (no clone)

Our sandbox pipeline is the swipe stack `seqtoid-ssot-infra/infra/state-foundation/workflows`, which names
everything `idseq-swipe-${environment}-*`. So a fully isolated chaos copy is `environment=sandbox-chaos`:

```
environment = sandbox-chaos   # -> idseq-swipe-sandbox-chaos-* : own SFN, Batch CEs/queues/job-defs, buckets
                              #    in account 941377154785, on its OWN terraform workspace (never touches
                              #    the sandbox pipeline's state)
```

`workflows/main.tf` tags every resource `seqtoid.io/chaos-sandbox=true` **only** when the env name contains
"chaos" (`strcontains`), so the copy is guard-eligible and the real `idseq-swipe-sandbox-*` pipeline is not.

## The two safety mechanisms (unchanged from the dev design)

1. **Fail-closed target guard** — `guard-sandbox.yaml` (chaos-sandbox-guard ConfigMap): every experiment
   sources it and refuses any target not BOTH named `idseq-swipe-sandbox-chaos-*` AND tagged
   `seqtoid.io/chaos-sandbox=true`. Name alone can't be spoofed; the tag comes only from a sandbox-chaos apply.
2. **Dual gate** — a fault passes only if availability (SLO probe `/steady-state`) AND accuracy (a benchmark
   run at AUPR ≥ 0.98 + checksum integrity) both hold under it. The benchmark is S3-self-contained (its own
   sandbox-chaos prefix), so a faulted run can't corrupt the app DB / OpenSearch.

## Stand up  (deliberate — do NOT run casually)

1. **Stand up the disposable copy** (own workspace so it never touches sandbox state):
   ```
   cd seqtoid-ssot-infra/infra/state-foundation/workflows
   terraform workspace new sandbox-chaos
   AWS_PROFILE=idseq-support terraform apply -var=name_prefix=seqtoid -var=environment=sandbox-chaos
   ```
   -> `idseq-swipe-sandbox-chaos-*` SFN + Batch + aligner queues, tagged `seqtoid.io/chaos-sandbox=true`.
   Also upload the WDLs + dispatch a test sample against this copy (see env-reconstitute/tools/, with
   ENVIRONMENT=sandbox-chaos) so a benchmark can run.
2. **Render the experiments** for the copy + fill the `REPLACE-*` queue/SFN suffixes with the actual
   `idseq-swipe-sandbox-chaos-*` names:
   ```
   ./render-sandbox-experiments.sh          # -> ./rendered/{_sandbox-guard,p1..p6}.yaml
   ```
3. **Chaos Mesh + probes up** (already installed on sandbox from the web-tier gameday): apply the SLO +
   accuracy probes scoped to `sandbox-chaos`.

## Prove recovery FIRST (mandatory, before arming any fault)

```
terraform destroy (sandbox-chaos workspace) && terraform apply   # rebuild the copy from code
# then one clean benchmark on the idseq-swipe-sandbox-chaos SFN -> confirm AUPR >= 0.98
```
This proves the pipeline is reconstructable from code. Only then arm faults.

## Run one experiment

```
kubectl apply -f rendered/_sandbox-guard.yaml
kubectl apply -f rendered/p1-batch-job-kill.yaml    # one at a time
kubectl -n chaos-mesh get workflow dual-gate-p1-batch-job-kill -w
```
P2/P4/P5/P6 also need the sandbox FIS templates: adapt `../fis/fis-experiment-templates.tf` with
`deployment_environment=sandbox-chaos` (account 941377154785) — same tag-scoping, or fold them into the
`seqtoid-ssot-infra/infra/chaos-fis/` stack.

| P | Fault | Proves |
|---|-------|--------|
| P1 | Batch job-kill mid-alignment | SFN Retry re-runs the job; AUPR still ≥ 0.98 |
| P2 | Spot interruption | spot->on-demand fallback; run completes |
| P3 | Scratch (disk) exhaustion on the aligner CE | job fails cleanly + retries, no corruption |
| P4 | S3 fault (read/write error) | s3parcp retries; run survives a transient S3 blip |
| P5 | SFN task fault | the state machine's error handling / Retry path |
| P6 | ECR throttle | image-pull backoff tolerated |

## Tear down (disarm)

```
kubectl delete -f rendered/
# FIS: aws fis stop-experiment any running; terraform destroy the sandbox-chaos FIS templates
cd seqtoid-ssot-infra/infra/state-foundation/workflows
terraform workspace select sandbox-chaos && terraform destroy -var=name_prefix=seqtoid -var=environment=sandbox-chaos
terraform workspace select sandbox        # back to the real sandbox workspace
```
Buckets are `force_destroy`, so nothing is orphaned. Kill switch: remove the experiment manifests +
`aws fis stop-experiment`; the real `idseq-swipe-sandbox-*` pipeline is never in the target set.

## Remaining to make it one-command-armable (follow-ups)

- Fill the `REPLACE-*` suffixes in the rendered experiments from the actual sandbox-chaos names.
- Author the sandbox-chaos FIS templates (P2/P4/P5/P6) in `chaos-fis/` or `../fis/`.
- Deploy the SLO + accuracy probes with a `sandbox-chaos` scope.
