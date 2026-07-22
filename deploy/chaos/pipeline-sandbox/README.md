# Pipeline-chaos sandbox -- the disposable IaC copy (platform-overhaul #794/#808)

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

## The P-series experiments (instantiate templates/dual-gate.yaml)

Each is a `dual-gate` Workflow (availability SLO + accuracy AUPR/integrity), targeting the
sandbox only:

| P | Fault | Asserts |
|---|-------|---------|
| P1 | kill a Batch job mid-alignment | SFN Retry re-runs it; AUPR holds |
| P2 | FIS spot-interrupt during a task | pipeline tolerates interruption it must already survive |
| P3 | **scratch-volume exhaustion** (reproduce #799 on the sandbox) | the per-DB split-volume fix holds; run completes |
| P4 | S3 intermediate delay / IOChaos | timeouts/retries absorb it; no wrong output |
| P5 | SFN task-transition fault | Retry/Catch config is actually correct |
| P6 | ECR pull throttle | run slows, does not fail (cached layers) |

P3 is the flagship: it turns the NT/NR disk incident (#799) from "found in production" into
"proven fixed, on a schedule, on a disposable copy."

## Build order (#808)

1. Add a `dev-chaos` env to workflow-infra (tfvars + state key); tag all its resources
   `seqtoid.io/chaos-sandbox=true`.
2. Prove `destroy`/`apply`/benchmark recovery.
3. Author P1-P6 as `dual-gate` instances with the sandbox-tag target guard.
4. Wire the accuracy probe (templates/dual-gate.yaml) at the sandbox SFN.
5. Only then arm, one experiment at a time, per DESIGN.md section 13.
