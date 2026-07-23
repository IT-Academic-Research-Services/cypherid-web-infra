# Pipeline-chaos sandbox -- runbook (platform-overhaul #794/#808)

On-call one-pager for the disposable `dev-chaos` pipeline sandbox. **NOT APPLIED yet** -- this is the
procedure for when it is armed. Full detail: `README.md`. Design rationale: `../DESIGN.md` section 9.

## What this is

A throwaway copy of the genomics pipeline (`idseq-dev-chaos-*` SFN / Batch / Lambda / buckets) in the
dev account, on its own terraform state key, that the P1-P6 chaos experiments fault. The shared
`idseq-dev-*` pipeline is never a target.

## The two things that keep it safe

1. **Tag guard, fail closed.** Every experiment's inject node sources `experiments/_sandbox-guard.yaml`
   and refuses any target that is not both named `idseq-dev-chaos-*` AND tagged
   `seqtoid.io/chaos-sandbox=true`. That tag is applied only by a `dev-chaos` terraform apply.
2. **Dual gate.** An experiment passes only if availability (SLO probe `/steady-state`) AND accuracy
   (a sandbox benchmark run at AUPR >= 0.98 + checksum integrity) both hold under the fault. Either
   gate breaking aborts the run and removes the fault.

## Stand up

```
cd cypherid-workflow-infra && source environment.dev-chaos && make deploy
```

## Prove recovery (before arming -- mandatory)

```
terraform destroy && make deploy   # then one clean benchmark, confirm AUPR >= 0.98
```

## Run one experiment

```
kubectl apply -f deploy/chaos/pipeline-sandbox/experiments/_sandbox-guard.yaml
kubectl apply -f deploy/chaos/pipeline-sandbox/experiments/<pN>.yaml
kubectl -n chaos-mesh get workflow dual-gate-<pN> -w
```

FIS-based experiments (P2/P4/P5/P6) also need the FIS templates applied first:
`cd deploy/chaos/pipeline-sandbox/fis && terraform apply -var enable_chaos_fis=true -var deployment_environment=dev-chaos ...`

## If something looks wrong

- **Fault seems to be hitting shared dev.** It cannot by construction, but STOP anyway: delete the
  Workflow (`kubectl delete -f .../experiments/<pN>.yaml`), `aws fis stop-experiment` any running FIS
  experiment, and check the guard log line (`GUARD: ...`) in the inject pod -- it prints the exact
  target it approved. File a ticket if the target was not `idseq-dev-chaos-*`.
- **Accuracy gate fails (AUPR < 0.98) under fault.** This is a real finding -- the pipeline lost
  correctness under the fault. Triage like a Sentry issue (the verdict node already opened a ticket):
  is it a genuine resilience gap (fix the pipeline) or an experiment-tuning issue (too-harsh fault)?
- **Availability gate fails.** SLO breach during the fault; same triage. The Grafana window is
  annotated `chaos` + the experiment name.

## Tear down (disarm)

```
kubectl delete -f deploy/chaos/pipeline-sandbox/experiments/
cd deploy/chaos/pipeline-sandbox/fis && terraform destroy -var enable_chaos_fis=true -var deployment_environment=dev-chaos
cd cypherid-workflow-infra && source environment.dev-chaos && terraform destroy
```

## Cost

Near-zero idle (`minvCpus=0`; free-at-rest definitions). Cost accrues only during an experiment's
benchmark run. `terraform destroy` between campaigns removes even the idle footprint; sandbox buckets
are `force_destroy` so nothing is orphaned.
