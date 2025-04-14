data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_id]
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

# data "aws_secretsmanager_secret" "okta" {
#   name     = "prod/okta/api_key"
#   provider = aws.czi-si
# }

# data "aws_secretsmanager_secret_version" "okta" {
#   secret_id = data.aws_secretsmanager_secret.okta.id
#   provider  = aws.czi-si
# }

# provider "okta" {
#   org_name  = "czi-prod"
#   api_token = data.aws_secretsmanager_secret_version.okta.secret_string
# }
# # this is needed because fogg adds okta/okta in the okta-head and it confuses
# # the providers passed to submodules. TODO: remove the fogg bug
# # for now, configure both providers so they don't throw provider configuration errors
# provider "okta-head" {
#   org_name  = "czi-prod"
#   api_token = data.aws_secretsmanager_secret_version.okta.secret_string
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