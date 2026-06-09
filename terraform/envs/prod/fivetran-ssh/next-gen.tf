locals {
  name                = "${var.tags.project}-${var.tags.env}-${var.tags.service}"
  fivetran_ssh_server = "34.48.124.245"
  rds_high_port       = "13306"
  rds_port            = "3306"
  image_arn           = "${var.aws_accounts.idseq-prod}.dkr.ecr.us-west-2.amazonaws.com/czid-fivetran-ssh:latest"
  mount_path          = "/var/secrets"
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
          name  = local.name
          image = local.image_arn

          port {
            container_port = 80
          }

          # only difference between this container and the entities container is the high port
          env {
            name  = "SSH_HIGH_PORT"
            value = local.rds_high_port
          }

          env {
            name  = "RDS_PORT"
            value = local.rds_port
          }

          env {
            name  = "RDS_ADDRESS"
            value = "idseq-prod-0.cpamsctm1mg0.us-west-2.rds.amazonaws.com"
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
