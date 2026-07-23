#!/usr/bin/env python3
"""
Chaos Engine -- verdict reporter (auto-ticket + Grafana annotation). platform-overhaul #794/#812.

The last node of every experiment Workflow (see templates/dual-gate.yaml). It closes the loop the
#794 epic is about -- turn a chaos finding into a tracked ticket automatically, the same shape as the
Sentry sweep -- and makes the morning-after review one click:

  1. ALWAYS post a Grafana annotation over the experiment window (release-marker style) so App RED /
     ALB 5xx / Loki / Tempo can be read against the fault at a glance.
  2. On a FAILED verdict (availability OR accuracy gate broke), open a Forgejo ticket with the
     experiment, which gate(s) failed, and a deep link to the annotated Grafana window.

Dependency-free (urllib). Reads tokens from the mounted secret (env). Never fails the Workflow itself
-- reporting is best-effort; a reporter error must not mask the experiment verdict.

  report.py --experiment <name> --verdict pass|fail [--gate availability|accuracy ...] [--detail "..."]

Env: GRAFANA_URL, GRAFANA_TOKEN, FORGEJO_URL, FORGEJO_TOKEN, FORGEJO_REPO (owner/repo),
     CHAOS_START_EPOCH_MS, CHAOS_END_EPOCH_MS (set by the Workflow).
NOT DEPLOYED. Built as chaos-report:latest; wired via the verdict node once the tokens exist (#700 SMTP
is not required -- these are API tokens, not mail).
"""
import argparse, json, os, sys, urllib.request

def _post(url, token, payload, auth="Bearer"):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"{auth} {token}")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read().decode()[:200]
    except Exception as e:  # best-effort: never raise
        return None, f"{type(e).__name__}: {e}"

def grafana_annotation(name, verdict, gates, detail):
    url = os.environ.get("GRAFANA_URL")
    if not url:
        return "skip (no GRAFANA_URL)"
    body = {
        "time": int(os.environ.get("CHAOS_START_EPOCH_MS", "0")) or None,
        "timeEnd": int(os.environ.get("CHAOS_END_EPOCH_MS", "0")) or None,
        "tags": ["chaos", f"verdict:{verdict}", name] + [f"gate-failed:{g}" for g in gates],
        "text": f"Chaos Engine: {name} -> {verdict.upper()}. {detail}".strip(),
    }
    body = {k: v for k, v in body.items() if v is not None}
    code, msg = _post(url.rstrip("/") + "/api/annotations", os.environ.get("GRAFANA_TOKEN"), body)
    return f"grafana annotation: {code} {msg}"

def forgejo_ticket(name, gates, detail):
    url, repo = os.environ.get("FORGEJO_URL"), os.environ.get("FORGEJO_REPO")
    if not (url and repo):
        return "skip (no FORGEJO_URL/REPO)"
    g = ", ".join(gates) or "unknown"
    body = (
        f"Auto-filed by the Chaos Engine verdict reporter (#794).\n\n"
        f"**Experiment:** {name}\n**Failed gate(s):** {g}\n**Detail:** {detail}\n\n"
        f"Grafana window is annotated (tag `chaos`, `{name}`). Triage like a Sentry finding: "
        f"is this a real resilience gap (ticket + fix) or an experiment-tuning issue?"
    )
    payload = {"title": f"Chaos FAIL: {name} broke the {g} gate", "body": body,
               "labels": []}  # label ids filled at deploy; kept empty so this is portable
    code, msg = _post(f"{url.rstrip('/')}/api/v1/repos/{repo}/issues",
                      os.environ.get("FORGEJO_TOKEN"), payload, auth="token")
    return f"forgejo ticket: {code} {msg}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--experiment", required=True)
    ap.add_argument("--verdict", choices=["pass", "fail"], required=True)
    ap.add_argument("--gate", action="append", default=[])
    ap.add_argument("--detail", default="")
    a = ap.parse_args()
    print(grafana_annotation(a.experiment, a.verdict, a.gate, a.detail))
    if a.verdict == "fail":
        print(forgejo_ticket(a.experiment, a.gate, a.detail))
    else:
        print("verdict pass -- no ticket")
    return 0  # never fail the Workflow on a reporting error

if __name__ == "__main__":
    sys.exit(main())
