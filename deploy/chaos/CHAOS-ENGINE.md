# The Chaos Engine -- design & north star (platform-overhaul #794)

Working name: **Chaos Engine.** This is the architecture we are building toward:
**Netflix-parity or better** resilience testing for the seqtoid platform. `DESIGN.md`
is the operational catalog (the manifests you apply); this doc is the *why* and the
*target shape*. Everything is **BUILT, NOT DEPLOYED** until the arm checklist in
`DESIGN.md` section 13.

---

## Mission: prove the system stays UP *and* RIGHT under fault

Every other chaos platform, Netflix's included, gates on **one** thing: availability
("did the service keep answering?"). The Chaos Engine gates on **two**, because our
product is a *scientific instrument* -- a wrong answer delivered with 100% uptime is
still a failure:

1. **Availability** -- the platform stays within its SLOs during and after the fault
   (5xx rate, ALB 5xx, p99 latency, pods-Ready, job success rate, queue depth).
   Measured by the **SLO probe** (`slo-probe/`) against the LGTM/Mimir stack.
2. **Accuracy** -- the platform still produces *correct results* under the fault:
   - a benchmark sample run completes and holds **AUPR >= 0.98** (the #388 gate), and
   - a **data-integrity checksum** (the taxon-lineage `CHECKSUM`-fingerprint pattern)
     shows **zero corruption** of reference data / results after the fault clears.

**A Chaos Engine experiment passes only if BOTH gates hold.** This dual gate is the
core reason the Chaos Engine is *better than Netflix* for our domain, not just at
parity: Netflix's ChAP proves "streams still start"; the Chaos Engine proves "the
pathogen call is still correct."

---

## Netflix parity scorecard

Parity is not "we have a Chaos Monkey." Netflix's real state of the art is three
systems most people never hear about -- FIT, ChAP, Monocle. Honest status:

| Netflix capability | What it is | Chaos Engine status |
|---|---|---|
| Simian Army fault menu | pod/net/stress/AZ/region faults | **DONE** -- Chaos Mesh + AWS FIS (E1-E8, E4/AZ/RDS) |
| **FIT** | request-level fault injection (fail a % of one dependency) | **DONE** -- E7 HTTPChaos |
| **SLO auto-abort** | automatic pass/fail, inline abort | **DONE (v1)** -- SLO probe (threshold) |
| **ChAP** | canary + control clusters, live-traffic split, fault into canary only | **PRIMITIVES IN HAND** -- preview-sandboxes = canary/control; pingpong = traffic split. Wiring = #808/#813 |
| **Automated Canary Analysis** | *statistical* canary-vs-control KPI comparison | **v2 upgrade of the SLO probe** -- #810 |
| **Monocle** | dependency-criticality map; prioritizes experiments; flags misconfig | **BUILDING** -- `criticality/` register + checker (#814) |
| Continuous, prioritized, in-prod | run always, risk-ranked, safely in prod | dev-only for now; prod is a separate gated decision |
| **Accuracy / correctness gate** | -- | **BETTER THAN NETFLIX** -- Netflix has none; ours is AUPR + data-integrity |

Two hardest ChAP primitives (canary/control + traffic-split) we already own via the
preview-sandbox + pingpong work. Netflix had to build those from scratch.

---

## Architecture (target)

```
                         +------------------ Chaos Engine control plane -------------------+
                         |                                                                 |
  Monocle (criticality)  |   experiment catalog (E-series web, P-series pipeline)          |
  criticality/register   +--> prioritizes --> Scheduler (overnight / randomized / CI-gate) |
  + checker (finds                                   |                                      |
  missing timeouts w/o                               v                                      |
  even injecting)                        Workflow: preflight -> INJECT fault -> [dual gate] |
                                                                     |                       |
                                    +--------------------------------+-------------------+   |
                                    v                                v                   v   |
                          AVAILABILITY gate               ACCURACY gate           auto-abort |
                          SLO probe (PromQL vs LGTM)   benchmark AUPR>=0.98 +    on either   |
                          [+ ACA: canary vs control]   checksum-fingerprint      gate break  |
                                    |                                |                       |
                                    +-------------> verdict + auto-ticket + Grafana overlay <-+
```

**Fault reach:** Chaos Mesh (pod/net/stress/IO/DNS/HTTP/time, in-cluster) + AWS FIS
(node/AZ/RDS/API-throttle, managed-service) -- together >= the Simian Army.

**Blast radius:** dev-only; the genomics pipeline is faulted only on a **disposable,
IaC-cloned `-chaos` copy** (never the shared dev pipeline) -- see `DESIGN.md` section 9.
Prod is out of scope until dev proves the full loop + a separate prod decision (ChAP-style
canary + business-metric abort make prod chaos safe when we get there).

---

## Components (build order)

1. **SLO probe** (availability gate) -- DONE, `slo-probe/`. #810 wires it in + adds ACA (v2).
2. **Monocle / criticality register** -- `criticality/`. Static map of every dependency's
   timeout/retry/fallback/criticality; the checker flags misconfig (bugs found without
   injecting) and ranks which experiments matter. #814.
3. **Dual-gate experiment template** -- `templates/dual-gate.yaml`: the reference Workflow
   that asserts availability + accuracy together. Every high-value experiment (esp. the
   pipeline P-series) instantiates it. #815.
4. **ChAP canary/control** -- fault into a preview-sandbox canary, matched control, compare.
   #813 (builds on the pipeline sandbox #808).
5. **Automated Canary Analysis** -- SLO probe v2: statistical canary-vs-control. #810.
6. **Continuous + CI-gate + observability** -- #811/#812.

The Chaos Engine is "done" (parity+) when: any experiment can be run as a canary/control
pair, auto-analyzed on availability AND accuracy, aborted automatically on either gate,
prioritized by the criticality map, and reported without a human -- on dev today, on prod
when we decide.
