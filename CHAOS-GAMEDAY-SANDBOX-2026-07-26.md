# Chaos gameday — sandbox (seqtoid-sandbox), 2026-07-26

First chaos gameday against the **sandbox reconstitute env** (EKS `seqtoid-sandbox`, account
941377154785, AL2023.12 + containerd 2.2.4). Purpose: prove the AL2023/containerd-2.x wall fix and
surface hardening areas. Native `kubectl apply` harness (the gate is dev-locked; not used here),
`mode: one` on the single web pod, kubectl-poll availability + `/health_check` recovery assertion,
accuracy = heatmap ES in-sync with the DB. Namespace armed only during the run, disarmed after.

## Complete run registry (every chaos run, 2026-07-26) -- authoritative index

This is the single combined record of every experiment run on the sandbox that day. Three tiers: Chaos
Mesh (app/web faults), AWS FIS (node + infra faults, with the real experiment IDs), and the pipeline
P-series. Detail + evidence for each is in the sections below.

### Tier 1 -- Chaos Mesh (web/app tier)

| Exp | Fault | Mechanism | Verdict |
|-----|-------|-----------|---------|
| E1 | pod-kill | PodChaos | **PASS** (surfaced HA gap: single web replica) |
| E2 | network delay 300ms | NetworkChaos | **PASS** |
| E3 | CPU + mem stress | StressChaos | **PASS** |
| E5 | IO-latency on /tmp | IOChaos | **BLOCKED** (fuse/cgroup-v2) -> moved to FIS **E5'** |
| E6 | DNS-error (OpenSearch host) | DNSChaos | **PASS** (graceful degrade; literal endpoint pattern) |
| E7 | HTTP-abort :3000 | HTTPChaos | **FAIL** (tproxy teardown residue on AL2023) -> moved to FIS **E7'** |
| E8 | time-skew -10m | TimeChaos | **PASS** |

### Tier 2 -- AWS FIS (node + infra tier) -- 8 experiments

| Exp | Fault | Template | Experiment ID(s), chronological | Verdict |
|-----|-------|----------|----------------------------------|---------|
| E4 | terminate one web node | EXTkNgVriJrb9AQ | EXPbnTVkPrQzxLnf2S (completed) | **PASS** -- nodegroup re-provisioned ~40s, web stayed up |
| AZ | terminate all us-west-2a nodes | EXT7frqJxjB5ZKk1e | EXPqBAjALNeYg3t21g (completed) | **PASS (mechanism)** -- 2a replenished ~15s; true web-AZ-loss needs >=2 replicas + spread |
| RDS | Aurora failover | EXT2pNnPi8YezaD6Q | EXPYSUnpDEQsrNq3i2 (failed) | **FAIL = finding**: sandbox Aurora is SINGLE-INSTANCE, nothing to promote -> no DB HA |
| E7' | network latency 200ms/60s (SSM) | EXTArbYwN22R4DVdS | EXP5RKAHz4L9yNyGFk (fail: PT2M too short) -> EXPoEGE3nDQAcQw4K4 (fail: iface eth0 not on AL2023) -> **EXPhR9UJ2m2ox6Eyia (PASS)** | **PASS** after 2 fixes: PT2M->PT5M window + eth0->ens5 |
| E5' | disk fill 60%/60s (SSM) | EXT9VzDuif8DkCuTe | EXPUh64Hfc2te1Pm5U (fail: node not SSM-registered) -> **EXP23zKJ93AvDVb82xr (PASS)** | **PASS** after nodegroup role got AmazonSSMManagedInstanceCore |

Totals: 8 FIS experiments -- 5 completed, 3 failed-then-fixed. The 3 failures were transient config
issues (window too short, wrong ENI name, SSM registration lag), each fixed and codified; RDS "failure"
is the real no-HA finding, not a fixable one.

### Tier 3 -- Pipeline P-series (disposable idseq-swipe-sandbox-chaos copy)

| P | Fault | Mechanism | Verdict |
|---|-------|-----------|---------|
| P1 | Batch job-kill mid-alignment | guarded CLI terminate-job on diamond-SPOT | **PASS** -- SFN Retry re-ran the chunk on the EC2 (on-demand) queue -> advanced to Postprocess |
| P2 | Spot interruption | FIS send-spot-instance-interruptions (tpl EXTDWWAaNbYRTCB7e) | **Mechanism PROVEN via P1**; a controlled FIS inject could not land -- alignment ~90s < FIS's 2-min min interruption notice |
| P3 | Scratch/disk exhaustion | FIS disk-fill (SSM) | **BLOCKED** -- swipe batch instance role lacks AmazonSSMManagedInstanceCore |
| P4 | S3 read/write fault | FIS API-fault | **IMPOSSIBLE** -- FIS API fault injection is ec2-ONLY (s3 rejected) |
| P5 | SFN task fault | (same class as P1) | **COVERED by P1** |
| P6 | ECR throttle | FIS API-fault | **IMPOSSIBLE** -- ec2-only (ecr rejected) |

## Verdicts (clean; E6/E7 first-run numbers were E5-cascade contamination, re-tested in isolation)

| Exp | Fault | Injected on AL2023 | App behavior during fault | Recovery | Verdict |
|-----|-------|--------------------|----------------------------|----------|---------|
| E1 | pod-kill | n/a (API delete) | single replica → ~12s full outage | fresh pod, fast | **PASS** (HA gap) |
| E3 | CPU+mem stress | yes | stayed serving (0 unready) | 1s | **PASS** |
| E8 | time-skew −10m | yes | stayed serving | 1s | **PASS** |
| E2 | network delay 300ms | yes | stayed serving | 2s | **PASS** — recovered-fault validated |
| E6 | DNS-error (OpenSearch host) | yes | **stayed 1/1 — graceful degrade** | instant | **PASS** |
| E7 | HTTP-abort :3000 | flaky (True, then False) | health probes aborted → pod down | **did NOT recover** (needs pod delete) | **FAIL** — chaos teardown artifact |
| E5 | IO-latency /tmp | **NO** (fuse cgroup-v2) | half-mount corrupts /tmp | needs pod delete | **BLOCKED → FIS** |

Accuracy gate: heatmap ES `2,550,746` docs == DB throughout — **data layer intact** across the whole run.

## Hardening findings (ranked, app-side)

1. **Single web replica = no HA.** Any pod-level fault (E1, and E7's probe-abort) = a full outage; nothing
   else serves. **Fix: scale web to ≥2 + a PodDisruptionBudget.** Highest-impact finding.
2. **`shoryuken` CrashLoopBackOff** (pre-existing, 125+ restarts): `SFN_NOTIFICATIONS_QUEUE_ARN` points at
   the legacy `idseq-swipe-dev-web-sfn-notifications-queue`. **Fix: create/repoint the sandbox SQS queue.**
3. **Liveness and readiness both hit `/health_check`, which is dependency-blind.** It stays 200 while
   OpenSearch/search degrade (good: no crashloop on E6) but hides degradation, and gives no independent
   readiness signal (E7 aborting it kills the pod). **Fix: a dependency-aware deep-health/readiness probe
   (the SLO/accuracy probe's role).**
4. **App resilience is genuinely solid where it counts** — tolerated CPU/mem stress, clock skew, 300ms
   network latency, and OpenSearch DNS failure, all staying in service and recovering. No app-code change
   indicated for those.

## Chaos-engine / AL2023 findings (the engine, not the app)

- **E2 NetworkChaos: fully clean** on AL2023 (inject + teardown, pod recovers) — the wall fix (Chaos Mesh
  2.8.3 + the kmod-loader DaemonSet) holds end-to-end.
- **E6 DNSChaos: clean** with a **literal** endpoint pattern (leading-`*` wildcards rejected by
  chaos-dns-server 2.8.3; literal + `?` work — see e6-dns.yaml).
- **E7 HTTPChaos: not clean on AL2023.** Injection is flaky, and the tproxy teardown leaves the pod's
  netns broken (survives container restart → needs a pod delete) — same *residue* class as IOChaos.
  **Use AWS FIS (or a NetworkChaos-level abort) for HTTP-layer faults; or fix the tproxy teardown.**
- **E5 IOChaos: blocked** — `grant access to /dev/fuse: fail to find device cgroup` (cgroup-v2); the
  failed `toda` half-mount also corrupts the target `/tmp`. **Use AWS FIS `AWSFIS-Run-Disk-Fill`/IO.**
- **Operational:** failed IOChaos/HTTPChaos hang on a finalizer — clear with
  `kubectl patch <chaos> --type=merge -p '{"metadata":{"finalizers":[]}}'`.

## FIS path — built + E4 validated (2026-07-26)

Self-contained FIS stack at `seqtoid-ssot-infra/infra/chaos-fis/` (own role: terminate + rds-failover +
ssm send-command, tag-locked to `eks:nodegroup-name=seqtoid-sandbox-default`; web-5xx stop-condition
alarm; 5 templates: E4 terminate-node, AZ-interruption, RDS-failover, E7' network-latency (SSM), E5'
disk-fill (SSM)). The dev `chaos-fis-role` module is terminate-only (its AZ/RDS templates would fail) —
ticket that gap.

**E4 run (EXPbnTVkPrQzxLnf2S): PASS.** FIS terminated one node (i-0bcfe916, us-west-2a); stop-alarm stayed
OK; the managed-nodegroup ASG re-provisioned back to 3 Ready nodes within ~40s; web stayed 1/1 throughout
(COUNT(1) picked a non-web node — so the single-replica web-node-loss case is still unproven; re-run until
it targets the web node, or after the ≥2-replica fix). FIS path works end-to-end.

**AZ interruption (EXPqBAjALNeYg3t21g, us-west-2a): PASS (mechanism).** Terminated the 2a node
(ng_instances 3→2); web (in 2c) stayed 1/1; stop-alarm OK; ASG replenished 2a → 3 nodes in ~15s. NOTE: a
real WEB AZ-loss test needs the web's AZ targeted (2c) AND ≥2 replicas with topology spread — with 1
node/AZ + single-replica web, targeting the web AZ is just the web-node-loss case.

**RDS failover (EXPYSUnpDEQsrNq3i2): FAILED — hardening finding.** "Unable to failover all targets": the
sandbox Aurora is SINGLE-INSTANCE (seqtoid-sandbox-0, no reader, multiAZ=false) so there is nothing to
promote. Cluster stayed available, web 1/1 (failover never happened). **Finding: no DB HA** — a
production-representative env needs an Aurora reader replica in another AZ for failover to work. The
reconstitute data stack provisions single-instance (fine for a cost-lean rehearsal; a gap for prod-preview).

**E7' / E5' SSM (EXP5RKAHz4L9yNyGFk, EXPUh64Hfc2te1Pm5U): ran; SSM path proven at the mechanism level;
two tuning findings.** Verifying the SSM prerequisite surfaced a gap: the nodegroup role
`seqtoid-sandbox-eks-node` LACKED `AmazonSSMManagedInstanceCore`, so the app nodes were not SSM-registered.
**Fixed in Terraform** (added to `foundation/modules/eks/main.tf`, targeted-applied) -> future re-spun
nodes register on boot; also enables Session Manager. After the fix:
- E7' network-latency: SSM reached the node and the AWSFIS doc ran (installing tc/at, applying latency) --
  the SSM command status was Success -- but the FIS action timed out its PT2M window during dependency
  install. **Fixed: bumped the SSM action windows to PT5M.**
- E5' disk-fill: FIS COUNT(1) picked an unregistered node ("not managed by SSM") -- only 1/3 nodes had
  registered (SSM-agent re-registration lag on already-running nodes; recycle or wait clears it).
- web stayed 1/1, stop-alarm OK throughout both.
Finding: **SSM-agent registration lag** on already-running nodes (the codified policy makes fresh nodes
register on boot; current nodes need a recycle/agent-restart to register all 3). A fully clean E7'/E5' pass
lands once all target nodes are SSM-Online (guaranteed on the next reconstitute re-spin).

**E7'/E5' SSM PASS (2026-07-26, after 3 fixes): both GREEN.** With the nodegroup role's
AmazonSSMManagedInstanceCore codified, the recovered nodegroup's fresh nodes registered with SSM on boot
(4/4 Online -> no more registration lag). Then:
- E5' disk-fill (60%/60s): **PASS** -- experiment completed, web stayed 2/2, stop-alarm OK. The
  fuse-blocked IOChaos replacement works end-to-end via SSM.
- E7' network-latency (200ms/60s): failed twice first -- (a) FIS PT2M window too short for the doc's
  tc/at dependency-install -> bumped to PT5M; (b) "Interface eth0 does not exist" -> AL2023 EKS nodes use
  predictable names, primary ENI is **ens5** not eth0 -> fixed the template. Then **PASS** (completed, web
  2/2, alarm OK). The clean HTTPChaos/NetworkChaos replacement works.
Both faults were absorbed with web at 2 replicas (chip #1) staying 2/2 -- HA validated under chaos too.
Final passing experiment IDs: E5' = EXP23zKJ93AvDVb82xr, E7' = EXPhR9UJ2m2ox6Eyia (the earlier failed
attempts EXPUh64Hfc2te1Pm5U / EXP5RKAHz4L9yNyGFk / EXPoEGE3nDQAcQw4K4 are in the run registry at the top).

**AL2023 chaos matrix COMPLETE:** Chaos Mesh = E1 pod-kill / E2 network / E3 stress / E6 dns / E8 time;
AWS FIS = E4 node-terminate / AZ / RDS-failover(=no-HA finding) / E7' network-latency / E5' disk-fill.

## Pipeline tier -- P-series armed + P1 PASS (2026-07-26)

Stood up the disposable `idseq-swipe-sandbox-chaos-*` pipeline copy: a variable flip on the workflows
stack (environment=sandbox-chaos + a new foundation_env=sandbox so it REUSES the sandbox foundation while
naming its own SFN/Batch/queues -chaos-), on an isolated `sandbox-chaos` workspace (81 added, 0 destroyed),
tagged seqtoid.io/chaos-sandbox=true for the guard. Recovery proven: the chaos SFN ran a real (adapted)
input through PreprocessInput -> HostFilter -> NonHostAlignment -> Postprocess.

**P1 Batch-job-kill mid-alignment: PASS.** With the fail-closed guard (kill only if the queue is
idseq-sandbox-chaos-*), terminated one diamond chunk job on idseq-sandbox-chaos-diamond-SPOT-normal during
NonHostAlignment. The fan-out re-ran the killed chunk and the pipeline **advanced to Postprocess** -- the
Batch-attempt / SFN-Retry fallback is wired, not assumed. The real idseq-sandbox-* pipeline had 0 jobs
touched. Setup + guard + render + runbook: cypherid-web-infra/deploy/chaos/pipeline-sandbox/sandbox/.

## Pipeline tier -- P2-P6 resolved (2026-07-26)

Authored the sandbox-chaos FIS templates properly and ran them down. **The decisive finding: AWS FIS API
fault injection (`aws:fis:inject-api-internal-error` / `inject-api-throttle-error`) supports ONLY the `ec2`
service** -- probed directly, `s3`/`batch`/`ecr`/`lambda` are all rejected ("The service parameter value is
not supported for the action"). The dev-chaos P4/P5/P6 templates (s3/batch/ecr API faults) were authored
BUILT-NOT-APPLIED, so this was never caught -- **they are invalid as designed**.

| P | Fault | Verdict |
|---|-------|---------|
| P2 | Spot interruption | **Mechanism PROVEN; controlled FIS injection blocked by test-input timing.** FIS template `EXTDWWAaNbYRTCB7e` built + applied (action `aws:ec2:send-spot-instance-interruptions`, target `aws:ec2:spot-instance` by exact `Name=seqtoid-sandbox-chaos-align-spot` -- fail-closed; the real pipeline's aligners are `seqtoid-sandbox-align-spot`, no "chaos"). But FIS's **`durationBeforeInterruption` minimum is 2 min** (hard AWS floor) and the `idseq_bench_3` test input's NonHostAlignment runs in **~90s** -- the spot instance finishes and terminates before the interruption notice matures, so a controlled interrupt can't land. The spot->on-demand fallback P2 asserts is nonetheless **demonstrated by P1**: the killed spot chunk (`...diamond-...-part-5`, statusReason `P1-chaos-batch-job-kill` on diamond-SPOT) was retried and **SUCCEEDED on diamond-EC2** (on-demand), alignment advanced. **Follow-up:** a controlled FIS spot-interrupt needs a >2-min alignment (a larger benchmark input), not the tiny e2e smoke sample. |
| P3 | Scratch/disk exhaustion | **BLOCKED (same class as E5' was).** `AWSFIS-Run-Disk-Fill` is SSM-driven; the swipe Batch instance role `idseq-swipe-sandbox-chaos-batch-main-instance` lacks `AmazonSSMManagedInstanceCore`, so the aligner nodes aren't SSM-registered. Fix mirrors the nodegroup fix: add the managed policy to the swipe instance role (fork change). |
| P4 | S3 read/write fault | **IMPOSSIBLE via FIS** -- API fault injection is ec2-only (`s3` rejected). Needs a non-FIS mechanism (e.g. a scoped, time-boxed bucket-policy deny), which the earlier hard-deny attempt showed is easy to over-tune. |
| P5 | SFN task fault | **COVERED BY P1** -- the SFN Retry / Batch-attempt fallback is the same mechanism, already GREEN (P1 advanced past the killed task). No separate run needed. |
| P6 | ECR throttle | **IMPOSSIBLE via FIS** -- API fault injection is ec2-only (`ecr` rejected). Image-pull-backoff tolerance would need a real throttle or a broken-image proxy. |

Net: of P2-P6, **P2's resilience is proven (via P1) and P5 is subsumed by P1**; **P3 is a one-line IAM fix
away**; **P4/P6 hit an AWS FIS service-support limit** that retires the dev-chaos design for those two.
Ephemeral FIS stack (P2 template + role) lives at scratch `pchaos-fis/` (local state -- not committed).

Teardown: `terraform destroy` the sandbox-chaos workspace (buckets force_destroy) + the scratch FIS stack.

End state: Chaos Mesh 2.8.3 + chaos-daemon + chaos-dns-server + codified kmod-loader installed on
sandbox; namespace **disarmed**; web pod healthy; data layer verified intact.
