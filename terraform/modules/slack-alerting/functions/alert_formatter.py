"""env-alerting: format a CloudWatch alarm state-change into a short, Slack-friendly message.

Slack's email-to-channel integration SILENTLY DROPS raw CloudWatch->SNS alarm emails (a wall of
JSON). It renders short PLAIN-TEXT emails fine, but SNS email is text-only -- no markdown, no HTML.
So this Lambda receives the alarm state-change via EventBridge, builds a compact message, and
publishes it to the SNS topic (whose email subscription is the Slack channel address).

Bold labels use sans-serif-bold UNICODE (U+1D5D4 A.. / U+1D5EE a..) because the channel renders the
body as plain text; blank lines between fields keep it scannable. Format approved by Tom (SMP-1679).
"""
import os
import boto3

sns = boto3.client("sns")
TOPIC = os.environ["TOPIC_ARN"]
ENV = os.environ.get("ENV_LABEL", "env")

# ASCII -> sans-serif-bold unicode, so labels read as bold in a plain-text email.
_UP = {chr(ord("A") + i): chr(0x1D5D4 + i) for i in range(26)}
_LO = {chr(ord("a") + i): chr(0x1D5EE + i) for i in range(26)}


def bold(s):
    return "".join(_UP.get(c, _LO.get(c, c)) for c in s)


def handler(event, ctx):
    d = event.get("detail", {}) or {}
    name = d.get("alarmName", "?")
    st = d.get("state", {}) or {}
    state = st.get("value", "?")
    reason = st.get("reason", "") or ""
    desc = (d.get("configuration") or {}).get("description", "") or ""
    t = event.get("time", "")

    if state == "ALARM":
        header = f"\U0001F534 {bold(ENV + ' ALERT')}"
    elif state == "OK":
        header = f"✅ {bold(ENV + ' RECOVERED')}"
    else:
        return {"skipped": state}

    # Optional "Runbook:" suffix in the alarm description is split out to its own line.
    what, runbook = desc, ""
    if "Runbook:" in desc:
        what, runbook = [p.strip() for p in desc.split("Runbook:", 1)]

    parts = [header, "", f"{bold('Alarm')}:  {name}", "", f"{bold('State')}:  {state}"]
    if what:
        parts += ["", f"{bold('What')}:  {what}"]
    if reason:
        parts += ["", f"{bold('Why')}:  {reason[:400]}"]
    parts += ["", f"\U0001F551 {t}"]
    if runbook:
        parts += [f"\U0001F527 {bold('Runbook')}:  {runbook}"]

    sns.publish(
        TopicArn=TOPIC,
        Subject=f"{ENV} {state}: {name}"[:99],
        Message="\n".join(parts),
    )
    return {"published": True}
