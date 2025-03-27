
locals {
  auto_apply              = true
  default_branch          = "main"
  teams_with_write_access = ["team-sci-idseq-eng", "team-sci-idseq-dev"]
  organization            = "idseq-infra"
  repo                    = "chanzuckerberg/idseq-infra"
  ssh_key_name            = "czi-si-tfe"
  tags                    = var.tags
}
