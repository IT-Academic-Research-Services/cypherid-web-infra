#!/usr/bin/env python3
"""
Chaos Engine -- criticality checker (the "Monocle" static analysis). platform-overhaul #794/#814.

Reads dependency-register.yaml and does what Netflix's Monocle does before any fault is injected:
  1. FINDINGS -- flag every `critical` dependency that lacks a real timeout or fallback (or is still
     TODO-AUDIT). These are resilience bugs found WITHOUT injecting anything -- the cheapest wins.
  2. PRIORITY -- rank chaos experiments: critical + not-safe_to_fail first (highest risk, test/fix
     soonest), optional + safe_to_fail last.

Exit non-zero if any critical dependency has an unresolved timeout/fallback -- so this can gate CI
(a new critical dependency without a fallback fails the build, before it ever reaches a chaos night).

Usage:  python3 check_criticality.py [dependency-register.yaml]   (pyyaml optional; falls back to a tiny parser)
"""
import sys, os

REG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "dependency-register.yaml")
MISSING = {"", "none", "todo-audit", "sdk-default", "runtime-default", "per-task", "job attempt"}


def load(path):
    try:
        import yaml
        return yaml.safe_load(open(path))
    except Exception:
        pass
    # minimal fallback parser for the flat register (list of single-level dicts)
    deps, cur = [], None
    for raw in open(path):
        line = raw.rstrip("\n")
        if line.startswith("  - name:"):
            cur = {"name": line.split("name:", 1)[1].strip()}
            deps.append(cur)
        elif cur is not None and line.startswith("    ") and ":" in line:
            k, v = line.strip().split(":", 1)
            cur[k.strip()] = v.strip().strip('"')
    return {"dependencies": deps}


def unresolved(v):
    return str(v).strip().lower() in MISSING


def main():
    reg = load(REG)
    deps = reg.get("dependencies", [])
    findings, ranked = [], []
    for d in deps:
        crit = d.get("criticality", "optional")
        safe = str(d.get("safe_to_fail", "false")).lower() == "true"
        name = d.get("name", "?")
        # FINDINGS: a critical dependency with no timeout or no fallback is a latent resilience bug
        if crit == "critical":
            if unresolved(d.get("timeout", "")):
                findings.append(f"[timeout]  critical dependency '{name}' has no verified timeout ({d.get('timeout')!r})")
            if unresolved(d.get("fallback", "")):
                findings.append(f"[fallback] critical dependency '{name}' has no fallback ({d.get('fallback')!r}) and safe_to_fail={safe}")
        # PRIORITY score: higher = test/fix sooner
        score = {"critical": 100, "important": 50, "optional": 10}.get(crit, 0) + (0 if safe else 25)
        ranked.append((score, name, crit, safe, d.get("chaos", "")))

    print("== Chaos Engine criticality check ==\n")
    print("EXPERIMENT PRIORITY (highest risk first):")
    for score, name, crit, safe, chaos in sorted(ranked, reverse=True):
        flag = "" if safe else "  <- NO proven fallback: FIX before trusting the experiment"
        print(f"  [{score:>3}] {name:<16} {crit:<9} safe_to_fail={str(safe):<5}{flag}")
        if chaos:
            print(f"        experiments: {chaos}")
    print(f"\nFINDINGS ({len(findings)}) -- resilience gaps found WITHOUT injecting a fault:")
    for f in findings:
        print(f"  - {f}")
    if not findings:
        print("  (none -- every critical dependency has a verified timeout + fallback)")

    # gate: fail if any critical dependency is unresolved
    hard = [f for f in findings if f.startswith("[timeout]") or "no fallback" in f]
    if hard:
        print(f"\nRESULT: FAIL -- {len(hard)} critical dependency gap(s). Resolve in dependency-register.yaml (audit + wire fallbacks).")
        return 1
    print("\nRESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
