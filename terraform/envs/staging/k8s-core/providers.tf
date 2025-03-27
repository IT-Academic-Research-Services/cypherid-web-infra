data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_ssm_parameter" "dd_app_key" {
  name     = "/shared-infra-prod-datadog/app_key"
  provider = aws.czi-si
}
data "aws_ssm_parameter" "dd_api_key" {
  name     = "/shared-infra-prod-datadog/api_key"
  provider = aws.czi-si
}

provider "datadog" {
  app_key = data.aws_ssm_parameter.dd_app_key.value
  api_key = data.aws_ssm_parameter.dd_api_key.value
}

data "aws_secretsmanager_secret" "opsgenie" {
  name     = "prod/opsgenie/api_key"
  provider = aws.czi-si
}

data "aws_secretsmanager_secret_version" "opsgenie" {
  secret_id = data.aws_secretsmanager_secret.opsgenie.id
  provider  = aws.czi-si
}

provider "opsgenie" {
  api_key = data.aws_secretsmanager_secret_version.opsgenie.secret_string
}
