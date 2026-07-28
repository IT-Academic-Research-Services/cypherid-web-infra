#!/usr/bin/env python3
"""
Chaos Engine -- verdict reporter (auto-ticket + Grafana annotation). platform-overhaul #794/#812.

The last node of every experiment Workflow (see templates/dual-gate.yaml). It closes the loop the
#794 epic is about -- turn a chaos finding into a tracked ticket automatically, the same shape as the
Sentry sweep -- and makes the morning-after review one click:

  1. ALWAYS post a Grafana annotation over the experiment window (release-marker style) so App RED /
     ALB 5xx / Loki / Tempo can be read against the fault at a glance.
  2. On a FAILED verdict (availability OR accuracy gate broke), open a JIRA ticket -- a Task under the
     bug-bucket epic (SMP-761), UNASSIGNED -- with the FULL story: what fault was injected, the
     sequence/timeline of what happened, what was observed, which gate failed and by how much, and a
     deep link to the annotated Grafana window. Jira is used (not the localhost Forgejo) because the
     reporter runs in-cluster and Jira Cloud is reachable from there. NOTE: the ticket body does NOT
     reference Forgejo / platform-overhaul #NNN numbers -- those are not resolvable by Jira viewers.

Dependency-free (urllib). Each HTTP call uses its OWN opener (build_opener) so the Grafana request can
never leak connection/redirect state into the Jira request. Never fails the Workflow itself --
reporting is best-effort; a reporter error must not mask the experiment verdict.

  report.py --experiment <name> --verdict pass|fail
            [--gate availability|accuracy ...]        # which gate(s) FAILED (repeatable)
            [--fault "<what was injected + params>"]
            [--step "<t> <what happened>" ...]         # sequence/timeline (repeatable, in order)
            [--observed "<what was seen>"]
            [--failure "<gate: measured vs threshold>"]
            [--metric "<name>=<value>" ...]            # key numbers (repeatable)
            [--detail "<freeform>"]

Env: GRAFANA_URL, GRAFANA_TOKEN, GRAFANA_BROWSE_URL, CHAOS_DASHBOARD_UID, JIRA_BASE_URL, JIRA_EMAIL,
     JIRA_TOKEN, JIRA_PROJECT (default SMP), JIRA_PARENT (default SMP-761),
     CHAOS_START_EPOCH_MS, CHAOS_END_EPOCH_MS (set by the Workflow).
"""
import argparse, base64, json, os, sys, urllib.request


def _http(url, headers, payload):
    """POST with an ISOLATED opener so no global urllib state carries between calls. Best-effort."""
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.build_opener().open(req, timeout=15) as r:
            return r.status, r.read().decode()[:300]
    except Exception as e:  # best-effort: never raise
        return None, f"{type(e).__name__}: {e}"


def grafana_link():
    """Deep link to the annotated fault window (browsable Grafana + chaos dashboard uid + range)."""
    browse = os.environ.get("GRAFANA_BROWSE_URL") or os.environ.get("GRAFANA_URL")
    if not browse:
        return None
    start = os.environ.get("CHAOS_START_EPOCH_MS", "")
    end = os.environ.get("CHAOS_END_EPOCH_MS", "")
    uid = os.environ.get("CHAOS_DASHBOARD_UID", "seqtoid-dev-chaos")
    q = "&".join(p for p in [f"from={start}" if start else "", f"to={end}" if end else ""] if p)
    return f"{browse.rstrip('/')}/d/{uid}" + (f"?{q}" if q else "")


def grafana_annotation(name, verdict, gates, detail):
    url = os.environ.get("GRAFANA_URL")
    if not url:
        return "grafana annotation: skip (no GRAFANA_URL)"
    body = {
        "time": int(os.environ.get("CHAOS_START_EPOCH_MS", "0")) or None,
        "timeEnd": int(os.environ.get("CHAOS_END_EPOCH_MS", "0")) or None,
        "tags": ["chaos", f"verdict:{verdict}", name] + [f"gate-failed:{g}" for g in gates],
        "text": f"Chaos Engine: {name} -> {verdict.upper()}. {detail}".strip(),
    }
    body = {k: v for k, v in body.items() if v is not None}
    tok = os.environ.get("GRAFANA_TOKEN")
    headers = {"Authorization": f"Bearer {tok}"} if tok else {}
    code, msg = _http(url.rstrip("/") + "/api/annotations", headers, body)
    return f"grafana annotation: {code} {msg}"


# --- ADF (Atlassian Document Format) builders: Jira Cloud v3 needs ADF, not plain text ------------
def _p(text):
    return {"type": "paragraph", "content": [{"type": "text", "text": text}]}

def _h(text, level=3):
    return {"type": "heading", "attrs": {"level": level}, "content": [{"type": "text", "text": text}]}

def _bullets(items):
    return {"type": "bulletList", "content": [
        {"type": "listItem", "content": [_p(str(i))]} for i in items if str(i).strip()]}

def _link_para(label, url):
    return {"type": "paragraph", "content": [
        {"type": "text", "text": label},
        {"type": "text", "text": url, "marks": [{"type": "link", "attrs": {"href": url}}]}]}


def build_description(a, gafana_url):
    """Rich, sectioned ticket body: summary, fault injected, sequence, what was observed, what
    failed, key metrics, and links. Only sections with content are emitted. Deliberately carries NO
    Forgejo / #NNN references -- those are not resolvable by Jira viewers."""
    g = ", ".join(a.gate) or "unknown"
    content = [
        _p(f"Auto-filed by the Chaos Engine verdict reporter. Experiment '{a.experiment}' FAILED its "
           f"dual gate: the {g} gate broke under the injected fault."),
    ]
    if a.fault:
        content += [_h("Fault injected"), _p(a.fault)]
    if a.step:
        content += [_h("Sequence"), _bullets(a.step)]
    if a.observed:
        content += [_h("What happened"), _p(a.observed)]
    if a.failure or a.gate:
        content += [_h("What failed"), _p(a.failure or f"The {g} gate did not hold under the fault.")]
    if a.metric:
        content += [_h("Key metrics"), _bullets(a.metric)]
    if a.detail:
        content += [_h("Detail"), _p(a.detail)]
    content += [_h("Links")]
    if gafana_url:
        content.append(_link_para("Grafana (annotated fault window): ", gafana_url))
    content.append(_p("Triage like a Sentry finding: is this a real resilience gap (fix the system) "
                      "or an experiment-tuning issue (too-harsh fault)?"))
    return {"type": "doc", "version": 1, "content": content}


def jira_ticket(a, grafana_url):
    """Open a Jira Task on a failed verdict, UNASSIGNED, under the bug-bucket epic (SMP-761)."""
    base = os.environ.get("JIRA_BASE_URL")
    email = os.environ.get("JIRA_EMAIL")
    token = os.environ.get("JIRA_TOKEN")
    if not (base and email and token):
        return "jira ticket: skip (no JIRA_BASE_URL/EMAIL/TOKEN)"
    project = os.environ.get("JIRA_PROJECT", "SMP")
    parent = os.environ.get("JIRA_PARENT", "SMP-761")  # Milestone X1 bug bucket epic
    g = ", ".join(a.gate) or "unknown"
    fields = {"project": {"key": project}, "issuetype": {"name": "Task"},
              "summary": f"Chaos FAIL: {a.experiment} broke the {g} gate",
              "description": build_description(a, grafana_url),
              "labels": ["chaos", "chaos-verdict"]}
    if parent:
        fields["parent"] = {"key": parent}  # no assignee field on purpose -> UNASSIGNED
    auth = "Basic " + base64.b64encode(f"{email}:{token}".encode()).decode()
    code, msg = _http(base.rstrip("/") + "/rest/api/3/issue", {"Authorization": auth}, {"fields": fields})
    key = ""
    try:
        key = json.loads(msg).get("key", "")
    except Exception:
        pass
    return f"jira ticket: {code} {key or msg}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--experiment", required=True)
    ap.add_argument("--verdict", choices=["pass", "fail"], required=True)
    ap.add_argument("--gate", action="append", default=[])
    ap.add_argument("--fault", default="")
    ap.add_argument("--step", action="append", default=[])
    ap.add_argument("--observed", default="")
    ap.add_argument("--failure", default="")
    ap.add_argument("--metric", action="append", default=[])
    ap.add_argument("--detail", default="")
    a = ap.parse_args()
    link = grafana_link()
    print(grafana_annotation(a.experiment, a.verdict, a.gate, a.detail or a.observed))
    if a.verdict == "fail":
        print(jira_ticket(a, link))
    else:
        print("verdict pass -- no ticket")
    return 0  # never fail the Workflow on a reporting error


if __name__ == "__main__":
    sys.exit(main())
