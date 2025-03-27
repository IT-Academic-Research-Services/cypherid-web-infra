locals {
  name                    = "${var.tags.project}-${var.tags.env}-${var.tags.service}"
  fivetran_ssh_server     = "35.235.101.244"
  rds_high_port_workflows = "25433"
  rds_high_port_entities  = "25432"
  rds_port                = "5432"
  image_arn               = "745463180746.dkr.ecr.us-west-2.amazonaws.com/czid-fivetran-ssh:latest"
  mount_path              = "/var/secrets"
}

resource "kubernetes_deployment_v1" "fivetran_ssh" {
  metadata {
    name      = local.name
    namespace = data.terraform_remote_state.happy.outputs.namespace
    labels = {
      app = local.name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.name
      }
    }

    template {
      metadata {
        labels = {
          app = local.name
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }

        # workflows db
        container {
          name  = "${local.name}-workflows"
          image = local.image_arn

          port {
            container_port = 80
          }

          # only difference between this container and the entities container is the high port
          env {
            name  = "SSH_HIGH_PORT"
            value = local.rds_high_port_workflows
          }

          env {
            name  = "RDS_PORT"
            value = local.rds_port
          }

          env {
            name  = "FIVETRAN_SSH_SERVER"
            value = local.fivetran_ssh_server
          }

          volume_mount {
            name       = "fivetran-private-key"
            mount_path = local.mount_path
          }
        }

        # entities db
        container {
          name  = "${local.name}-entities"
          image = local.image_arn

          port {
            container_port = 80
          }

          env {
            name  = "SSH_HIGH_PORT"
            value = local.rds_high_port_entities
          }

          env {
            name  = "RDS_PORT"
            value = local.rds_port
          }

          env {
            name  = "FIVETRAN_SSH_SERVER"
            value = local.fivetran_ssh_server
          }

          volume_mount {
            name       = "fivetran-private-key"
            mount_path = local.mount_path
          }
        }
        volume {
          name = "fivetran-private-key"

          secret {
            secret_name = module.parameters.secret_name
          }
        }
      }
    }
  }
}

module "parameters" {
  source = "git@github.com:chanzuckerberg/shared-infra//terraform/modules/kubernetes-secret-from-aws-param?ref=v0.395.0"

  project = var.tags.project
  env     = var.tags.env
  service = var.tags.service
  owner   = var.tags.owner

  aws_ssm_iam_role_name = data.terraform_remote_state.k8s-core.outputs.aws_ssm_iam_role_name

  namespace   = data.terraform_remote_state.happy.outputs.namespace
  secret_name = "fivetran-private-key"
}
