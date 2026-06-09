provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  # token                  = data.aws_eks_cluster_auth.cluster.token
  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_id, "--profile", var.aws_profile]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    # token                  = data.aws_eks_cluster_auth.cluster.token
    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_id, "--profile", var.aws_profile]
    }
  }
}

# data "aws_ssm_parameter" "dd_app_key" {
#   name     = "/shared-infra-prod-datadog/app_key"
#   provider = aws.czi-si
# }
# data "aws_ssm_parameter" "dd_api_key" {
#   name     = "/shared-infra-prod-datadog/api_key"
#   provider = aws.czi-si
# }

# provider "datadog" {
#   app_key = data.aws_ssm_parameter.dd_app_key.value
#   api_key = data.aws_ssm_parameter.dd_api_key.value
# }

# data "aws_secretsmanager_secret" "opsgenie" {
#   name     = "prod/opsgenie/api_key"
#   provider = aws.czi-si
# }

# data "aws_secretsmanager_secret_version" "opsgenie" {
#   secret_id = data.aws_secretsmanager_secret.opsgenie.id
#   provider  = aws.czi-si
# }

# provider "opsgenie" {
#   api_key = data.aws_secretsmanager_secret_version.opsgenie.secret_string
# }
