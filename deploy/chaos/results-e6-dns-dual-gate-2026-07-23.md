# Chaos experiment E6 -- DNS dependency failure -- dual-gate test result

| | |
|---|---|
| **Experiment** | E6 -- DNSChaos `action: error`, OpenSearch host, `mode: one` |
| **Verdict** | **PASS** -- fault injected, both gates held, zero pod restarts |
| **Significance** | **First successful E6 injection ever**, and the **first dual-gate supervised run** on this platform |
| **Date/time** | 2026-07-24 ~02:40 UTC |
| **Environment** | dev -- EKS `czid-dev-eks`, namespace `seqtoid-dev`, account 491013321714, us-west-2 |
| **Run mode** | Attended, supervised, armed and disarmed in-session |
| **Operator** | Tom (approved), executed in-session |
| **Ticket** | design #794; upgrade #836; E6 unblock recorded here |

---

## 1. Objective / hypothesis

**Hypothesis:** making OpenSearch DNS resolution fail for a *single* web pod degrades
search/heatmap only -- it must NOT breach infra SLOs, crashloop the pod, or corrupt
reference data.

Two things made this run different from every prior chaos run:

1. **E6 had never injected.** On Chaos Mesh 2.7.2 the DNS/network/HTTP fault paths were
   dead against this cluster's cgroup v2 + containerd 2.x. E2/E6/E7 were blocked (Forgejo
   836). The 2.8.3 upgrade earlier today was performed specifically to unblock them, and
   this run is the first behavioural proof that it worked -- as opposed to reading a
   version string.
2. **It was supervised by a real dual gate.** Until today an experiment could only be
   judged on "did the app stay up". E6's own definition gates on
   `https://dev.seqtoid.org/health_check`, which is a weak signal (that endpoint is
   excluded from host authorization and can return 200 while the app is otherwise
   rejecting traffic). This run replaced both gate nodes with the real probes.

**Steady state, both halves:**

| gate | endpoint | asserts |
|---|---|---|
| availability | `chaos-slo-probe/steady-state` | PromQL SLOs (crashloops, failed pods, not-ready pods) |
| accuracy | `chaos-accuracy-probe/steady-state` (preflight) / `/run-under-fault` (during) | live `CHECKSUM TABLE` over `taxon_lineages` vs a captured baseline |

---

## 2. Method

Ran E6's fault **verbatim** -- same `action`, `mode`, selector and DNS pattern -- inside a
one-off Workflow whose preflight and in-flight gates were the two probes rather than
`/health_check`:

```
preflight-both-gates (Serial)   -> availability, then accuracy
inject-and-assert (Parallel)    -> DNSChaos + availability (Continuous) + accuracy (Continuous)
```

Blast radius, unchanged from the committed experiment: `mode: one` (a single pod), and the
pattern list contains **only** the OpenSearch host. The Aurora/RDS host is deliberately
excluded, because failing DB name resolution can break the app's reconnect path.

Armed with the namespace **annotation** (`chaos-mesh.org/inject=enabled`) -- an annotation,
not a label; the `enableFilterNamespace` guard keys off the annotation.

---

## 3. Result

**The fault injected.** This is the headline:

```
DNSChaos  dns-fail-dependency-whp87-2rbqg
records:  seqtoid-dev/czid-dev-seqtoid-web-5d787cdcfb-zgln9/rails   phase=Injected
```

`phase=Injected` against the `rails` container of one web pod is precisely what 2.7.2 could
not do on this kernel/runtime combination.

**Both gates held, before and after:**

| | pre-fault | post-fault |
|---|---|---|
| availability | `{"steady_state": true, "failed": []}` HTTP 200 | `{"steady_state": true, "failed": []}` HTTP 200 |
| accuracy | `{"pass": true, "integrity_ok": true}` HTTP 200 | `{"pass": true, "integrity_ok": true}` HTTP 200 |

**Pods:** both `1/1 Running`, **0 restarts**. No crashloop, no eviction.

**Hypothesis upheld:** losing OpenSearch DNS for one pod did not breach infra SLOs and did
not corrupt reference data.

---

## 4. FINDING -- an active fault does NOT self-recover, and disarming does not remove it

This is the most valuable output of the run, and it contradicts the design doc.

**Observed:** after the fault node's `deadline` elapsed, the `DNSChaos` object was still
`phase=Injected`. Removing the namespace annotation (the documented "instant global stop")
did **not** clear it. The fault only went away when the Workflow was deleted explicitly,
which cascaded to the chaos object.

**Why the design's safety net does not apply.** `DESIGN.md` section 4 claims:

> Bounded blast + auto-heal. Every fault has `mode: one` ..., **a hard `duration`, and Chaos
> Mesh's own recovery removes the fault** when the experiment ends or is deleted.

That invariant was quietly lost when the experiments were converted into Workflows. A chaos
`duration` is **illegal inside a Workflow node** -- E6's own comment records the change:

```yaml
deadline: 2m  # was chaos duration (illegal inside a Workflow); bounds the fault node
```

A node `deadline` bounds the *workflow node*. It does not give Chaos Mesh its own recovery
timer. So the self-healing property the design relies on is not present for any
Workflow-based experiment -- which is all of E1-E8.

**Why the documented rollback is wrong.** `DESIGN.md` step 7 says:

> **Disarm:** remove the `chaos-mesh.org/inject=enabled` annotation ... for an instant
> global stop
>
> Rollback is trivial: delete the inject annotation to disarm

Disarming prevents **new** injections. It does **not** remove an **already-injected** fault.
Anyone following the documented rollback during an incident would believe they had stopped
the experiment while the fault was still live.

**Correct teardown, verified in this run:**

```bash
kubectl -n chaos-mesh delete workflow <name>          # cascades to the chaos objects
kubectl -n chaos-mesh get podchaos,networkchaos,dnschaos,iochaos,httpchaos,stresschaos,timechaos
# ^ MUST return "No resources found" before you call the run finished
kubectl annotate ns seqtoid-dev chaos-mesh.org/inject-   # disarm (blocks NEW injections only)
```

Final state after this run was verified clean: zero chaos objects, annotation removed, both
pods healthy, both gates green.

---

## 5. What this run does and does not prove

**Proves:**
- Chaos Mesh 2.8.3 injects DNS faults on this cluster; the cgroup v2 / containerd 2.x
  blocker (Forgejo 836) is genuinely resolved. E2 and E7 are the same fault class and should
  now be runnable.
- The dual gate works end to end: preflight, in-flight supervision, and a verdict backed by
  a real content checksum rather than a liveness ping.
- A single pod losing a dependency's DNS is survivable at the SLO and data-integrity level.

**Does NOT prove:**
- **AUPR / scientific correctness.** The verdict carried `aupr_checked: false`. The accuracy
  gate ran integrity-only because no benchmark-trigger service exists yet, and the AUPR floor
  question is unresolved (the viral benchmark's reference AUPRs are ~0.24-0.43 against a 0.98
  floor). So this is "up and **uncorrupted**", not "up and **scientifically right**".
- **User-facing degradation.** The gates assert infra SLOs and data integrity; nothing in this
  run measured whether search/heatmap actually degraded *gracefully* from a user's
  perspective. E6's stated hypothesis includes that, and it remains untested.
- **Recovery behaviour.** Because the fault did not self-recover, this run did not exercise
  the "recovers cleanly when the fault lifts" half of the hypothesis.

---

## 6. Follow-ups

1. **Restore an auto-heal guarantee for Workflow-based faults** (the F1 of chaos safety).
   Options: a TTL reaper that deletes any chaos object older than N minutes regardless of
   workflow state -- mirroring the existing `seqtoid-sandbox-orphan-reaper` pattern -- and/or
   a guaranteed teardown node. A reaper is the stronger guarantee because it survives a stuck
   or abandoned workflow.
2. **Correct `DESIGN.md`**: the `duration`-based auto-heal claim and the "rollback is trivial"
   disarm instruction are both wrong as written.
3. **Measure user-facing degradation** in the next run, so E6's full hypothesis is tested.
4. **Wire the AUPR axis** so a verdict can assert correctness, not just integrity.
