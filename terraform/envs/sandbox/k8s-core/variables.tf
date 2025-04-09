locals {
  eks_cluster = data.terraform_remote_state.eks.outputs
  tags        = var.tags
  //TODO - Does UCSF use DataDog for monitoring?
  additional_addons = {
    # datadog = {
    #   mute                 = true
    #   api_key              = data.aws_ssm_parameter.dd_api_key.value
    #   ops_genie_owner_team = var.ie_ops_genie_team
    # }
  }
}