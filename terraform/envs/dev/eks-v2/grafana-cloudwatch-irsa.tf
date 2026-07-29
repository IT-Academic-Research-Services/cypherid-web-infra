# Observability Phase 4 (#608): IRSA role that lets Grafana READ CloudWatch metrics + logs, so the
# Grafana CloudWatch datasource (deploy/argocd/_deliberate/grafana-cloudwatch-datasource.yaml) can
# pull Step Functions / Lambda / Batch / RDS / ALB / S3 telemetry into dashboards + alerts WITHOUT
# touching those services. Read-only: no cloudwatch:Put*, no logs:Put*, no delete anywhere.
#
# BOOTSTRAP (post-apply): annotate the kps Grafana ServiceAccount with grafana_cloudwatch_role_arn
# below -- either via the kps chart values (grafana.serviceAccount.annotations."eks.amazonaws.com/
# role-arn") on the next kps sync, or live:
#   kubectl -n monitoring annotate sa kube-prometheus-stack-grafana \
#     eks.amazonaws.com/role-arn=<grafana_cloudwatch_role_arn> --overwrite
#   kubectl -n monitoring rollout restart deploy/kube-prometheus-stack-grafana
# If the role was created out-of-band (CLI) to light up the CloudWatch datasource ahead of a full
# eks-v2 apply, these import blocks make the next plan/apply ADOPT the existing role+policy instead of
# erroring on "EntityAlreadyExists". Harmless no-ops once the resources are in state; remove after the
# first apply that imports them.
import {
  to = aws_iam_role.grafana_cloudwatch
  id = "czid-dev-eks-v2-grafana-cloudwatch"
}
import {
  to = aws_iam_role_policy.grafana_cloudwatch
  id = "czid-dev-eks-v2-grafana-cloudwatch:cloudwatch-read"
}

data "aws_iam_policy_document" "grafana_cloudwatch_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks-cluster.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks-cluster.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:monitoring:kube-prometheus-stack-grafana"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks-cluster.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Read-only CloudWatch metrics + Logs Insights, mirrors Grafana's documented minimum policy.
data "aws_iam_policy_document" "grafana_cloudwatch" {
  # checkov:skip=CKV_AWS_356:CloudWatch metric + Logs Insights read APIs (GetMetricData, ListMetrics,
  # GetMetricStatistics, StartQuery, DescribeLogGroups, ec2/tag Describe for dimensions) are account-
  # wide and NOT resource-scopable; "*" is required and matches Grafana's documented CloudWatch policy.
  # All actions are read-only -- no Put/Create/Delete anywhere.
  statement {
    sid    = "CloudWatchMetricsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetInsightRuleReport",
    ]
    resources = ["*"] # CloudWatch metric reads are not resource-scopable
  }

  statement {
    sid    = "CloudWatchLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ResourceTagsForDimensions"
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "grafana_cloudwatch" {
  name               = "${local.cluster_name}-grafana-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.grafana_cloudwatch_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name   = "cloudwatch-read"
  role   = aws_iam_role.grafana_cloudwatch.id
  policy = data.aws_iam_policy_document.grafana_cloudwatch.json
}

output "grafana_cloudwatch_role_arn" {
  description = "IAM role ARN for the Grafana CloudWatch datasource -- annotate onto the kps Grafana ServiceAccount (see file header)."
  value       = aws_iam_role.grafana_cloudwatch.arn
}
