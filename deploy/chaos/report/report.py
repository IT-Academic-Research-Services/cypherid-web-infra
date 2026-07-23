#!/usr/bin/env python3
"""
Chaos Engine -- verdict reporter (auto-ticket + Grafana annotation). platform-overhaul #794/#812.

The last node of every experiment Workflow (see templates/dual-gate.yaml). It closes the loop the
#794 epic is about -- turn a chaos finding into a tracked ticket automatically, the same shape as the
Sentry sweep -- and makes the morning-after review one click:

  1. ALWAYS post a Grafana annotation over the experiment window (release-marker style) so App RED /
     ALB 5xx / Loki / Tempo can be read against the fault at a glance.
  2. On a FAILED verdict (availability OR accuracy gate broke), open a JIRA ticket (a Task under the
     bug-bucket epic) with the experiment, which gate(s) failed, and the annotated Grafana window.
     Jira is used rather than Forgejo because the reporter runs in-cluster and Jira Cloud is
     reachable from there, whereas the Forgejo instance is localhost-only.

Dependency-free (urllib). Reads tokens from the mounted secret (env). Never fails the Workflow itself
-- reporting is best-effort; a reporter error must not mask the experiment verdict.

  report.py --experiment <name> --verdict pass|fail [--gate availability|accuracy ...] [--detail "..."]

Env: GRAFANA_URL, GRAFANA_TOKEN, JIRA_BASE_URL, JIRA_EMAIL, JIRA_TOKEN, JIRA_PROJECT (default SMP),
     JIRA_PARENT (default SMP-761), CHAOS_START_EPOCH_MS, CHAOS_END_EPOCH_MS (set by the Workflow).
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

def _grafana_link():
    """Deep link to the annotated fault window so the ticket points straight at the data. Uses the
    BROWSABLE Grafana URL (grafana.dev.seqtoid.org) -- not the in-cluster GRAFANA_URL used to POST the
    annotation -- and the chaos dashboard UID + the experiment time range."""
    browse = os.environ.get("GRAFANA_BROWSE_URL") or os.environ.get("GRAFANA_URL")
    if not browse:
        return None
    start = os.environ.get("CHAOS_START_EPOCH_MS", "")
    end = os.environ.get("CHAOS_END_EPOCH_MS", "")
    uid = os.environ.get("CHAOS_DASHBOARD_UID", "seqtoid-dev-chaos")
    link = f"{browse.rstrip('/')}/d/{uid}"
    q = "&".join(p for p in [f"from={start}" if start else "", f"to={end}" if end else ""] if p)
    return f"{link}?{q}" if q else link

def _adf_doc(detail_txt, grafana_url):
    """ADF doc (Jira Cloud v3): a detail paragraph + a paragraph with a real clickable Grafana link."""
    content = [{"type": "paragraph", "content": [{"type": "text", "text": detail_txt}]}]
    if grafana_url:
        content.append({"type": "paragraph", "content": [
            {"type": "text", "text": "Grafana (annotated fault window): "},
            {"type": "text", "text": grafana_url,
             "marks": [{"type": "link", "attrs": {"href": grafana_url}}]},
        ]})
    return {"type": "doc", "version": 1, "content": content}

def jira_ticket(name, gates, detail):
    """Open a Jira ticket on a failed verdict, UNASSIGNED, as a Task under the bug-bucket epic
    (SMP-761) -- chaos findings sit with the rest of the tracked bugs. Includes a deep link to the
    annotated Grafana window. Jira is used (not the localhost Forgejo) because the reporter runs
    in-cluster and Jira Cloud is reachable from there. Basic auth = base64(email:token)."""
    base = os.environ.get("JIRA_BASE_URL")
    email = os.environ.get("JIRA_EMAIL")
    token = os.environ.get("JIRA_TOKEN")
    if not (base and email and token):
        return "skip (no JIRA_BASE_URL/EMAIL/TOKEN)"
    project = os.environ.get("JIRA_PROJECT", "SMP")
    parent = os.environ.get("JIRA_PARENT", "SMP-761")  # Milestone X1 bug bucket epic
    g = ", ".join(gates) or "unknown"
    grafana_url = _grafana_link()
    detail_txt = (
        f"Auto-filed by the Chaos Engine verdict reporter (platform-overhaul #794/#812). "
        f"Experiment: {name}. Failed gate(s): {g}. Detail: {detail}. "
        f"The Grafana window is annotated (tags chaos, {name}). Triage like a Sentry finding: "
        f"is this a real resilience gap (fix the system) or an experiment-tuning issue (too-harsh fault)?"
    )
    # Task under the bug epic, UNASSIGNED (no assignee field set on purpose).
    fields = {"project": {"key": project}, "issuetype": {"name": "Task"},
              "summary": f"Chaos FAIL: {name} broke the {g} gate",
              "description": _adf_doc(detail_txt, grafana_url), "labels": ["chaos", "chaos-verdict"]}
    if parent:
        fields["parent"] = {"key": parent}
    import base64
    auth = "Basic " + base64.b64encode(f"{email}:{token}".encode()).decode()
    req = urllib.request.Request(base.rstrip("/") + "/rest/api/3/issue",
                                 data=json.dumps({"fields": fields}).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", auth)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return f"jira ticket: {r.status} {json.loads(r.read() or '{}').get('key','?')}"
    except Exception as e:  # best-effort: never raise
        return f"jira ticket: err {type(e).__name__}: {e}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--experiment", required=True)
    ap.add_argument("--verdict", choices=["pass", "fail"], required=True)
    ap.add_argument("--gate", action="append", default=[])
    ap.add_argument("--detail", default="")
    a = ap.parse_args()
    print(grafana_annotation(a.experiment, a.verdict, a.gate, a.detail))
    if a.verdict == "fail":
        print(jira_ticket(a.experiment, a.gate, a.detail))
    else:
        print("verdict pass -- no ticket")
    return 0  # never fail the Workflow on a reporting error

if __name__ == "__main__":
    sys.exit(main())
