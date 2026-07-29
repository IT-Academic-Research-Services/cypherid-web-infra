# Full-suite chaos run against the sandbox env — plan

Goal: run the **whole** chaos matrix (E1–E8 web-tier + P-series pipeline + E4/FIS) against the live
**`seqtoid-sandbox`** EKS cluster to surface hardening areas — and in doing so, **break the AL2023 /
containerd-2.x wall** so the blocked four (E2/E5/E6/E7) actually run instead of being refused.

Status of the world (verified 2026-07-26):
- Target cluster `seqtoid-sandbox`, account `941377154785` (idseq-support). Kubecontext points at it.
- App is a live target: web pod + all resque monitors Running; `shoryuken` CrashLoopBackOff (pre-existing
  `SFN_NOTIFICATIONS_QUEUE_ARN` -> legacy `idseq-swipe-dev-…` gap — a finding, not chaos).
- Chaos Mesh is **NOT installed** on sandbox; **no Prometheus** (the SLO gate's dependency).
- Nodes: **Amazon Linux 2023.12 + containerd 2.2.4** — exactly the blocked combination.

## Why sandbox is a safe (ideal) target

- Isolated support account; not dev/staging/prod.
- **Rebuildable**: `reconstitute` (mechanism A) + the `seqtoid-sandbox-dataseed` snapshot = one-command
  restore of the whole env and its 2.55M-row data layer if a fault corrupts it.
- The chaos experiments fault the **k8s namespace `seqtoid-sandbox` (pods)** — NOT the similarly-named
  4.8 TB S3 research bucket. No experiment touches S3 objects; the pipeline P-series runs against a
  disposable `-chaos` copy, never shared/real data.

## Engine adaptations (it is currently dev-locked)

1. **Namespace**: every experiment hardcodes `selector.namespaces: [seqtoid-dev]`. We render
   sandbox **copies** under `deploy/chaos/.sandbox/` with `seqtoid-sandbox` (leave the dev originals
   untouched). StatusCheck URLs -> `https://sandbox.seqtoid.org/health_check`.
2. **Harness**: the gate (`staging-readiness-gate/run_gate.py`) is hard-locked to dev
   (`ALLOWED_ENVS={"dev"}`) and `chaos_resilience.sh` refuses non-dev namespaces. We do **NOT** lift those
   fail-closed guards. We drive sandbox with the **native `kubectl apply` harness** (DESIGN.md §5/§13)
   instead, one experiment at a time, arming via the namespace annotation.
3. **Availability gate**: SLO probe needs Prometheus (absent). Decision below — install a lite
   kube-prometheus-stack, or run a kubectl-poll availability sampler.
4. **Accuracy gate**: the accuracy probe runs a benchmark under fault (per-sample NT/NR AUPR ≥ 0.98) +
   a checksum integrity check. Sandbox already runs the pipeline e2e and holds the data, so we wire the
   probe to it (or a lighter taxon-count/heatmap-in-sync check for the first pass).

## Phase 0 — Pre-flight (non-destructive)

- Confirm kubecontext = `seqtoid-sandbox`; confirm `seqtoid-sandbox-dataseed` exists (restore net).
- Capture a **steady-state baseline**: pod readiness, restart counts, `/` 200s, heatmap ES in-sync,
  a benchmark AUPR baseline. This is what "recovered" is measured against.
- Node module inventory: `kubectl debug node/… -> chroot /host lsmod | grep -E 'sch_netem|ip_set|nf_tables'`.

## Phase 1 — Install + harden Chaos Mesh for AL2023 (solves the wall)

1. **Install Chaos Mesh 2.8.3** (the manifest is already bumped; the gate's "2.7.2 blocked" note is stale)
   into `chaos-mesh` ns, with:
   - `controllerManager.enableFilterNamespace=true` (annotation-arming),
   - `chaosDaemon.runtime=containerd`, `chaosDaemon.socketPath=/run/containerd/containerd.sock`,
   - `dnsServer.create=true` (for E6).
2. **modprobe DaemonSet** (privileged, hostPID) loading `sch_netem ip_set nf_tables cls_bpf` on every
   AL2023 node — the crux fix for E2/E7 (the "ipset flush" failure) and E6's redirect.
3. **FUSE for E5**: `fuse-device-plugin` DaemonSet (or a privileged `/dev/fuse` hostPath on the target).
4. **Arm**: `kubectl annotate ns seqtoid-sandbox chaos-mesh.org/inject=enabled --overwrite`
   (annotation, NOT label — a label will not work with enableFilterNamespace).

## Phase 2 — Gates on sandbox

- **Availability**: install lite `kube-prometheus-stack` (proper SLO PromQL gate) OR a kubectl-poll
  sampler (readiness + restart deltas + `/` 200-rate during the fault). See decision below.
- **Accuracy**: wire the accuracy probe to the sandbox pipeline benchmark + `/internal/chaos/integrity`;
  first pass may use the lighter check (heatmap ES docs == DB rows + a known-sample taxon-count).

## Phase 3 — Run the suite (one at a time; disarm between; assert recovery)

Order deliberately: known-good first (validate the rig), then the recovered four, then FIS, then pipeline.

| Step | Experiment | Expectation | Path |
|------|-----------|-------------|------|
| 3.1 | E1 pod-kill | PASS (proven on dev) | Chaos Mesh |
| 3.2 | E3 stress | PASS | Chaos Mesh |
| 3.3 | E8 time-skew | PASS | Chaos Mesh |
| 3.4 | E2 network delay+loss | **re-test @2.8.3 + modules** | Chaos Mesh; FIS `AWSFIS-Run-Network-Latency` fallback |
| 3.5 | E7 http-abort (FIT) | **re-test** | Chaos Mesh |
| 3.6 | E6 DNS failure | **re-test** (dnsServer + modules) | Chaos Mesh |
| 3.7 | E5 IO latency | **re-test** (FUSE) | Chaos Mesh; FIS `AWSFIS-Run-Disk-Fill`/IO fallback |
| 3.8 | E4 node/AZ/RDS | apply | AWS **FIS** (Terraform, retargeted to sandbox acct) |
| 3.9 | P1–P6 pipeline | apply | Chaos Mesh + AWS on a disposable `-chaos` pipeline copy |

For every step: confirm the **fault actually landed** (zero-impact = the fault missed = a fail), sample
**availability** throughout, run the **accuracy** probe under fault, disarm, then assert **unaided
recovery** within the budget. Anything Chaos-Mesh still can't inject on AL2023 after Phase 1 falls back
to the **FIS SSM** path (host-level, runtime-agnostic) so coverage is guaranteed.

## Phase 4 — Hardening report

Per experiment: fault-landed? availability held? accuracy held (AUPR ≥ 0.98 + integrity)? recovery time
vs budget. Aggregate into ranked **hardening areas**, each with a ticket. Known candidates already in
view: `shoryuken` crashloop (SFN notifications queue), blueGreen 503 ping-pong (#782), Karpenter eviction
behavior, and whatever the recovered four surface.

## Blast-radius controls (fail-safe)

- `mode: one` (one pod per experiment); scoped to `seqtoid-sandbox` ns only.
- Disarm between experiments; **global kill switch**:
  `kubectl annotate ns seqtoid-sandbox chaos-mesh.org/inject-` + delete the Schedules/Workflows.
- Recovery-budget assertion; auto-abort on SLO breach.
- **Data-layer recovery net**: `RECON_DB_SNAPSHOT=seqtoid-sandbox-dataseed` restore, or a full
  mechanism-A reconstitute, if any fault corrupts data.
- We never lift the gate's dev-lock or the staging/prod refusal; sandbox runs the native harness only.

## Two decisions for sign-off

1. **Availability gate**: lite kube-prometheus-stack (faithful SLO PromQL gate, ~1 extra install) **vs**
   kubectl-poll sampler (lighter/faster, less faithful). Recommend: **kubectl-poll for the first pass**,
   add Prometheus if we want the real SLO assertions.
2. **Scope of this run**: (a) **prove-the-wall-fix first** — Phase 1 + just re-test E2/E5/E6/E7 to confirm
   AL2023 is solved; or (b) **full matrix** — everything E1–E8 + FIS + P-series in one gameday. Recommend
   **(a) then (b)**: land the AL2023 fix and confirm the recovered four, then do the full gameday.
