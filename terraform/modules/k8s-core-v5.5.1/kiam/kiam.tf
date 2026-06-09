locals {
  kiam_server_fullname = "kiam-server"

  kiam_values = <<EOF
image:
  tag: v4.1
agent:
  host:
    iptables: true
    interface: "!eth0"
  resources:
    requests:
      memory: 100Mi
      cpu: 50m
    limits:
      memory: 400Mi
      cpu: 200m
  priorityClassName: ${var.priority_class}
server:
  # This cert host path is dependent on the underlying host OS. Currently hard coding for Amazon Linux 2
  sslCertHostPath: /etc/pki/ca-trust/extracted/pem
  tolerations:
  - effect: NoSchedule
    key: dedicated
    operator: Equal
    value: system_services
  - effect: NoExecute
    key: dedicated
    operator: Equal
    value: system_services
  nodeSelector:
    dedicated: system_services
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
  priorityClassName: ${var.priority_class}
serviceAccounts:
  server:
    annotations:
      eks.amazonaws.com/role-arn: ${module.kiam-role.iam_role_arn}
EOF
}

module "kiam-role" {
  source               = "github.com/chanzuckerberg/cztack//aws-iam-service-account-eks?ref=v0.104.2"
  eks_cluster          = var.eks_cluster
  iam_path             = var.iam_role_path
  k8s_namespace        = var.namespace
  service_account_name = local.kiam_server_fullname
  tags = merge(var.tags, {
    service = "${var.tags.service}-kiam"
  }) # TODO: var.tags is deprecated
}

data "aws_iam_policy_document" "kiam" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "kiam" {
  role   = module.kiam-role.iam_role
  policy = data.aws_iam_policy_document.kiam.json
}

resource "helm_release" "kiam" {
  name       = "kiam"
  repository = "https://uswitch.github.io/kiam-helm-charts/charts/"
  chart      = "kiam"
  version    = "6.1.2"
  namespace  = var.namespace
  values     = [local.kiam_values]
}
