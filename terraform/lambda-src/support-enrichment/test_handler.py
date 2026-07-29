"""Redaction + shaping tests for the support-enrichment handler (security-critical:
nothing unredacted may leave the function). Run: python -m pytest test_handler.py"""
import handler


def test_redact_collapses_sensitive_values():
    raw = (
        "failed at arn:aws:states:us-west-2:123456789012:execution:idseq-swipe-dev-x:run "
        "reading s3://idseq-samples-dev/1/2/x contact ops@example.com"
    )
    out, n = handler._redact(raw)
    assert "[REDACTED-ARN]" in out
    assert "[REDACTED-S3]" in out
    assert "[REDACTED-ACCT]" in out
    assert "[REDACTED-EMAIL]" in out
    assert "123456789012" not in out
    assert "s3://" not in out
    assert "@example.com" not in out
    assert n >= 4


def test_redact_none_is_safe():
    assert handler._redact(None) == (None, 0)


def test_handler_no_arn_returns_note_without_calling_aws():
    result = handler.handler({"correlation_id": "c1"}, None)
    assert result["correlation_id"] == "c1"
    assert "nothing to enrich" in result["note"]
    assert "sfn" not in result  # no AWS calls attempted
