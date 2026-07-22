# Pipeline-chaos sandbox -- the disposable IaC copy (platform-overhaul #794/#808)

> **NOT APPLIED -- awaiting Tom sign-off.** Every artifact here (the `dev-chaos` environment in
> `cypherid-workflow-infra`, the P1-P6 experiments, the FIS templates, the target guard) is
> **authored and wired to run behind a single flip, but nothing is deployed**: no `terraform apply`,
> no `kubectl apply`, no FIS start, no benchmark run. Arming is deliberate and staged (see
> "Stand-up / Run / Tear-down" and `../DESIGN.md` section 13). Disarm is always `terraform destroy`
> the sandbox + remove the experiment manifests.

The end-to-end half of the Chaos Engine: how we chaos-test the genomics pipeline
(S3 -> Step Functions -> Batch -> results) **without ever risking the one shared dev
pipeline.** This is the concrete answer to "test the prod pipeline, but don't break the
copy we can't recover." BUILT-DESIGN, NOT APPLIED.

## The key fact that makes this cheap + safe

`cypherid-workflow-infra` names **every** pipeline resource `idseq-${DEPLOYMENT_ENVIRONMENT}-*`
-- SFN state machines, Batch compute-envs/queues/job-defs, the `start_index_generation`
Lambda, buckets, alarms. `DEPLOYMENT_ENVIRONMENT` has **no value validation** (default
`test`). So a fully isolated copy of the pipeline is a **variable flip**, not a clone:

```
DEPLOYMENT_ENVIRONMENT = dev-chaos     # -> idseq-dev-chaos-* : own SFN, Batch, Lambda, buckets
AWS_ACCOUNT_ID         = 491013321714  # same dev account
# separate terraform state key/workspace so it never touches dev state
```

`terraform apply` stands up a parallel `idseq-dev-chaos-*` pipeline; `terraform destroy`
removes it. The shared `idseq-dev-*` pipeline is **never in the target set**. That IS the
"redundancy" -- not HA replicas, but a disposable copy that is cheap because it is code.

## Why it's safe (the four invariants, made concrete here)

1. **Isolated target.** Experiments select resources by the `idseq-dev-chaos-*` name /
   the `seqtoid.io/chaos-sandbox=true` tag only. A guard in every P-series experiment
   refuses any target not carrying that tag (mirrors the `managed_name?` guard in the
   taxon rollback).
2. **Transient faults only.** P-series faults kill *executions* (a Batch job, a spot
   instance, an SFN task, a Lambda invocation) -- never the SFN definition / Lambda code /
   Batch env (all re-created by `terraform apply`).
3. **Self-contained accuracy, no shared data.** The accuracy gate runs the benchmark
   (#388), which reads its inputs from and writes its outputs to the **sandbox's own S3
   prefix**, and computes AUPR from those S3 outputs vs ground truth. It does **not** write
   the shared app DB / OpenSearch, so a faulted run cannot corrupt real results. (Verify
   before first run: confirm the benchmark harness is S3-self-contained; if any step writes
   the app DB, point it at an isolated schema like the preview sandboxes do.)
4. **Recovery proven first.** Before enabling any experiment: `terraform destroy` the
   sandbox, `terraform apply` it back, and run one clean benchmark -> AUPR >= 0.98. That
   proves the whole pipeline is reconstructable from code. Only then arm the faults.

## Cost

Near-zero idle: Batch compute-envs sit at `minvCpus=0` (nothing runs = nothing billed);
SFN/Lambda/bucket definitions are free at rest. Cost is only the benchmark instances during
an experiment. Destroy the sandbox between campaigns.

## To verify before building (the honest unknowns)

- **VPC**: is `batch_vpc.tf` per-env (dev-chaos gets its own) or does it reference a shared
  dev VPC? Either is fine for chaos (the VPC is not a fault target), but confirm the apply
  does not collide on a shared-VPC resource name.
- **State backend**: workflow-infra uses fogg-managed state; add a `dev-chaos` env dir /
  state key so the copy is fully independent of dev state.
- **Global-unique names**: buckets/ECR are env-scoped (`-dev-chaos` is unique); confirm no
  resource uses a hardcoded (non-env) global name.

## The P-series experiments (authored -- `experiments/`)

Each is a full `dual-gate` Workflow (availability SLO + accuracy AUPR/integrity), targeting the
sandbox only, with the fail-closed target guard (`experiments/_sandbox-guard.yaml`) as the first
step of its inject node. Faults are AWS-native (the pipeline is SFN + Batch, not in-cluster): P1/P3
are guarded Batch-side scripts, P2/P4/P5/P6 start tag-scoped AWS FIS templates
(`fis/fis-experiment-templates.tf`).

| P | File | Fault | Asserts |
|---|------|-------|---------|
| P1 | `experiments/p1-batch-job-kill.yaml`     | terminate a Batch job mid-alignment       | SFN Retry re-runs it; AUPR holds |
| P2 | `experiments/p2-spot-interrupt.yaml`     | FIS spot-interrupt during a task          | pipeline tolerates interruption it must already survive |
| P3 | `experiments/p3-scratch-exhaustion.yaml` | **scratch-volume exhaustion** (repro #799) | the per-DB split-volume fix holds; run completes; AUPR holds |
| P4 | `experiments/p4-s3-fault.yaml`           | FIS S3 API errors on the sandbox job role | retries absorb it; no wrong output |
| P5 | `experiments/p5-sfn-task-fault.yaml`     | FIS Batch-API throttle -> SFN task fault  | Retry/Catch config is actually correct |
| P6 | `experiments/p6-ecr-throttle.yaml`       | FIS ECR API throttle on the instance role | run slows, does not fail (cached layers) |

P3 is the flagship: it turns the NT/NR disk incident (#799) from "found in production" into
"proven fixed, on a schedule, on a disposable copy."

## Stand-up / Run / Tear-down (the one-flip procedure)

All commands run in `cypherid-workflow-infra` (the pipeline IaC) except the `kubectl apply` of the
experiments, which run in this repo. **Nothing below has been run.**

### (a) Stand up the sandbox

```
# in cypherid-workflow-infra (branch: chaos-engineering-dev)
source environment.dev-chaos          # DEPLOYMENT_ENVIRONMENT=dev-chaos, same dev account, own state key
make deploy                            # package-lambdas + templates + init-tf (own backend) + terraform apply
```

`make deploy` stands up a parallel `idseq-dev-chaos-*` pipeline (own SFN, Batch queues/compute-envs,
Lambdas, VPC, buckets) under terraform state key `idseqdev-chaos` in the dev-account `-test` tfstate
bucket. The shared `idseq-dev-*` pipeline is **never in the target set**.

### (b) Prove recovery BEFORE arming any fault (safety invariant 4)

```
terraform destroy                      # tear the sandbox down
make deploy                            # stand it back up from code
# then run ONE clean benchmark on the sandbox SFN and confirm AUPR >= 0.98 (no fault)
```

This proves the whole pipeline is reconstructable from code. Only after a clean AUPR pass do you arm.

### (c) Apply the FIS templates (needed by P2/P4/P5/P6 only)

```
# in cypherid-web-infra/deploy/chaos/pipeline-sandbox/fis (apply via CI into the dev account)
terraform apply -var enable_chaos_fis=true -var deployment_environment=dev-chaos \
  -var 'sandbox_batch_job_role_arn=<from sandbox outputs>' \
  -var 'sandbox_sfn_execution_role_arn=<from sandbox outputs>' \
  -var 'sandbox_batch_instance_role_arn=<from sandbox outputs>'
```

### (d) Run one experiment (arm, one at a time)

```
# in cypherid-web-infra (Chaos Mesh + SLO probe + accuracy probe must already be up)
kubectl apply -f deploy/chaos/pipeline-sandbox/experiments/_sandbox-guard.yaml
kubectl apply -f deploy/chaos/pipeline-sandbox/experiments/p3-scratch-exhaustion.yaml   # e.g. the flagship
# watch: kubectl -n chaos-mesh get workflow dual-gate-p3-scratch-exhaustion -w
```

Each experiment self-verifies (dual gate) and the verdict node annotates Grafana + opens a Forgejo
ticket on failure. Repeat per P-file. Swap `p3-...` for any of P1-P6.

### (e) Tear down (disarm + stop the meter)

```
# remove the experiments (in cypherid-web-infra)
kubectl delete -f deploy/chaos/pipeline-sandbox/experiments/    # all P* + the guard
# destroy the FIS templates (in .../fis)
terraform destroy -var enable_chaos_fis=true -var deployment_environment=dev-chaos
# destroy the sandbox itself (in cypherid-workflow-infra, with environment.dev-chaos sourced)
terraform destroy
```

Idle cost is near-zero (Batch compute-envs sit at `minvCpus=0`; SFN/Lambda/bucket definitions are
free at rest), so leaving the sandbox up between runs is cheap -- but `terraform destroy` between
campaigns removes even that. The sandbox buckets are `force_destroy` (dev-chaos is in the
`data_force_destroy` list) so `destroy` leaves no orphaned billed buckets.

## Build order (#808) -- status

1. **DONE (authored).** `dev-chaos` env in workflow-infra (`environment.dev-chaos` + state-key
   routing in `environment`); all its resources tagged `seqtoid.io/chaos-sandbox=true` via the
   conditional `default_tags` local in `main.tf`; buckets made `force_destroy`.
2. **TODO (run).** Prove `destroy`/`apply`/benchmark recovery -- requires an apply, held for sign-off.
3. **DONE (authored).** P1-P6 as `dual-gate` instances with the sandbox-tag target guard
   (`experiments/`) + the FIS templates (`fis/`).
4. **DONE (authored) / TODO (wire).** The accuracy probe contract points `BENCHMARK_TRIGGER_URL` at
   the sandbox SFN (`../templates/dual-gate.yaml` ConfigMap). Fill the SFN ARN once the sandbox exists.
5. **TODO (arm).** Only then arm, one experiment at a time, per DESIGN.md section 13.

See `RUNBOOK.md` for the on-call one-pager.
