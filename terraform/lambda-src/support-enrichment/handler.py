"""Support-enrichment lambda -- Phase 2 (L2/L3) of the support pipeline-failure enrichment.

Invoked ASYNC by the Rails SupportEnrichmentJob after a support report about a failed
run is recorded. It pulls the deep failure detail the internet-facing web tier is
deliberately NOT allowed to read directly, and returns it ALREADY REDACTED:

  L2  Step Functions -- execution status, the state that failed, and its error/cause
      (DescribeExecution + GetExecutionHistory).
  L3  CloudWatch Logs -- a bounded tail of the FAILED Batch stage's log stream. SWIPE
      stages run as batch:submitJob.sync, so the log lives in a stream keyed by the
      Batch JOB ID, not the SFN execution name -- we resolve execution -> JobId (from
      history) -> log stream (via batch:DescribeJobs) -> tail.

Least privilege: this function's OWN execution role holds the scoped states:/logs:/batch:
read; the seqtoid-web role holds ONLY lambda:InvokeFunction on this function. Everything
that leaves here is redacted (ARNs, S3 URIs, account ids, emails), so nothing unredacted
crosses back into the app.

Event : {correlation_id, sfn_execution_arn, run_type, run_id}
Return: {correlation_id, run_type, run_id, sfn:{...}, logs:{...}, redactions:N}
"""
import json
import os
import re

import boto3

MAX_LOG_LINES = int(os.environ.get("MAX_LOG_LINES", "40"))
PIPELINE_LOG_GROUP = os.environ.get("PIPELINE_LOG_GROUP", "") or "/aws/batch/job"

# Lazy clients so the module imports without AWS creds/region (unit tests, cold checks).
_clients = {}


def _client(name):
    if name not in _clients:
        _clients[name] = boto3.client(name)
    return _clients[name]


# Collapse sensitive values to typed markers so an operator sees structure, not secrets.
_REDACTORS = [
    (re.compile(r"arn:aws[a-z-]*:[^\s\"']+"), "[REDACTED-ARN]"),
    (re.compile(r"s3://[^\s\"']+"), "[REDACTED-S3]"),
    (re.compile(r"\b\d{12}\b"), "[REDACTED-ACCT]"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "[REDACTED-EMAIL]"),
]


def _redact(text):
    if text is None:
        return text, 0
    out = str(text)
    total = 0
    for pattern, replacement in _REDACTORS:
        out, count = pattern.subn(replacement, out)
        total += count
    return out, total


def _sfn_detail(status, events):
    """L2: status + the failed state + the terminal error/cause, from the history."""
    detail = {"status": status}
    for event in events:
        etype = event.get("type", "")
        if etype == "ExecutionFailed":
            failed = event.get("executionFailedEventDetails", {})
            detail["error"] = failed.get("error")
            detail["cause"] = failed.get("cause")
        elif etype in ("TaskFailed", "TaskStateExited") and "failed_state" not in detail:
            state = event.get("stateExitedEventDetails") or {}
            if state.get("name"):
                detail["failed_state"] = state["name"]
    return detail


def _failed_batch_job_id(events):
    """Resolve the Batch JobId of the failed stage from the SFN history. SWIPE stages run
    as batch:submitJob.sync; the TaskSubmitted event carries the JobId in its output.
    Events are newest-first, so the first batch TaskSubmitted is the most recent (failed)
    task."""
    for event in events:
        if event.get("type") != "TaskSubmitted":
            continue
        details = event.get("taskSubmittedEventDetails") or {}
        resource = f"{details.get('resource', '')} {details.get('resourceType', '')}".lower()
        if "batch" not in resource:
            continue
        try:
            output = json.loads(details.get("output") or "{}")
        except (ValueError, TypeError):
            continue
        if output.get("JobId"):
            return output["JobId"]
    return None


def _log_tail(events):
    """L3: bounded tail of the FAILED Batch stage's actual CloudWatch log stream. Resolves
    the stream via the Batch JobId (the execution name is NOT the stream key). Best-effort
    -- any miss returns an empty tail with a note, never an error."""
    job_id = _failed_batch_job_id(events)
    if not job_id:
        return {"log_group": PIPELINE_LOG_GROUP, "tail": [], "note": "no batch job id in execution history"}

    try:
        jobs = _client("batch").describe_jobs(jobs=[job_id]).get("jobs", [])
    except Exception as exc:  # never fail the enrichment on a batch lookup
        return {"log_group": PIPELINE_LOG_GROUP, "batch_job_id": job_id, "tail": [], "note": f"describe_jobs failed: {type(exc).__name__}"}

    stream = (jobs[0].get("container") or {}).get("logStreamName") if jobs else None
    if not stream:
        return {"log_group": PIPELINE_LOG_GROUP, "batch_job_id": job_id, "tail": [], "note": "batch job has no log stream"}

    try:
        resp = _client("logs").get_log_events(
            logGroupName=PIPELINE_LOG_GROUP,
            logStreamName=stream,
            limit=MAX_LOG_LINES,
            startFromHead=False,
        )
        lines = [e.get("message", "").rstrip("\n") for e in resp.get("events", [])]
    except Exception as exc:
        return {"log_group": PIPELINE_LOG_GROUP, "log_stream": stream, "batch_job_id": job_id, "tail": [], "note": f"get_log_events failed: {type(exc).__name__}"}

    return {"log_group": PIPELINE_LOG_GROUP, "log_stream": stream, "batch_job_id": job_id, "tail": lines[-MAX_LOG_LINES:]}


def handler(event, _context):
    execution_arn = (event or {}).get("sfn_execution_arn")
    result = {
        "correlation_id": (event or {}).get("correlation_id"),
        "run_type": (event or {}).get("run_type"),
        "run_id": (event or {}).get("run_id"),
    }
    if not execution_arn:
        result["note"] = "no sfn_execution_arn; nothing to enrich"
        return result

    status = _client("stepfunctions").describe_execution(executionArn=execution_arn).get("status")
    events = _client("stepfunctions").get_execution_history(
        executionArn=execution_arn, reverseOrder=True, maxResults=100
    ).get("events", [])

    sfn = _sfn_detail(status, events)
    logs = _log_tail(events)

    redactions = 0
    for key in ("error", "cause", "failed_state", "status"):
        if key in sfn:
            sfn[key], count = _redact(sfn[key])
            redactions += count
    redacted_tail = []
    for line in logs.get("tail", []):
        line, count = _redact(line)
        redactions += count
        redacted_tail.append(line)
    logs["tail"] = redacted_tail

    result["sfn"] = sfn
    result["logs"] = logs
    result["redactions"] = redactions
    return result
