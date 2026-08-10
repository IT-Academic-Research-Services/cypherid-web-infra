"""env-alerting synthetic canary: probe a public URL from outside the cluster and emit a custom metric.

The ALB HealthyHostCount alarm catches "pods are unhealthy". This canary catches the layers ABOVE
that -- DNS, TLS cert, CloudFront/ALB routing, WAF, the app returning a non-error status -- by doing
a real HTTP GET against the public URL on a schedule and publishing SeqtoidSynthetics/SyntheticUp
(1 = 2xx/3xx, 0 = anything else or an exception). A CloudWatch alarm on that metric feeds the same
EventBridge -> formatter -> Slack path as every other alarm.
"""
import os
import urllib.request
import boto3

cw = boto3.client("cloudwatch")
URL = os.environ["CHECK_URL"]


def handler(event, ctx):
    up = 0
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": "seqtoid-synthetic-canary"})
        with urllib.request.urlopen(req, timeout=10) as r:
            up = 1 if 200 <= r.status < 400 else 0
    except Exception:
        up = 0
    cw.put_metric_data(
        Namespace="SeqtoidSynthetics",
        MetricData=[
            {
                "MetricName": "SyntheticUp",
                "Dimensions": [{"Name": "Url", "Value": URL}],
                "Value": up,
                "Unit": "Count",
            }
        ],
    )
    return {"url": URL, "up": up}
