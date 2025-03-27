locals {
  zone_id      = data.terraform_remote_state.idseq-dev.outputs.public_idseq_net_zone_id
  czid_zone_id = data.terraform_remote_state.idseq-dev.outputs.public_czid_org_zone_id
}
