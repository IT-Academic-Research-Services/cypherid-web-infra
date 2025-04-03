locals {
  node_pool_spec = {
    "disruption" = {
      "consolidationPolicy" = "WhenEmptyOrUnderutilized"
      "consolidateAfter"    = "24h"
    }

    "template" = {
      "spec" = {
        "expireAfter" = "720h" // 15 days

        "nodeClassRef" = {
          "group" = "karpenter.k8s.aws"
          "kind"  = "EC2NodeClass"
          "name"  = "default"
        }
        "requirements" = [
          {
            "key"      = "kubernetes.io/arch"
            "operator" = "In"
            "values" = [
              "arm64",
              "amd64",
            ]
          },
          {
            "key"      = "karpenter.sh/capacity-type"
            "operator" = "In"
            "values" = [
              "spot",
              "on-demand",
            ]
          },
          {
            "key"      = "kubernetes.io/os"
            "operator" = "In"
            "values" = [
              "linux",
            ]
          },
          {
            "key"      = "karpenter.k8s.aws/instance-size"
            "operator" = "NotIn"
            "values" = [
              "nano",
              "micro",
              "small",
            ]
          },
          # Required to make sure that our instances have enough ENIs on them
          # to work with the ebs-csi-node daemonset.
          {
            "key"      = "karpenter.k8s.aws/instance-cpu"
            "operator" = "Gt"
            "values" = [
              "8",
            ]
          },
          # Required to work with the ebs-csi-node daemonset, as it has a scheduling
          # restrictins against a1 instances. 
          {
            "key"      = "karpenter.k8s.aws/instance-family"
            "operator" = "NotIn"
            "values" : ["a1"]
          }
        ]
      }
    }
  }
}

resource "random_id" "node_pool_name" {
  byte_length = 4
  prefix      = "nodepool-"
  keepers = {
    # Regenerate nodepool definition every time spec changes
    version = yamlencode(local.node_pool_spec)
  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "kubectl_manifest" "karpenter_nodepool" {
  count = var.addons.enable_karpenter && var.addons.enable_default_karpenter_nodepool ? 1 : 0

  yaml_body = yamlencode({
    "apiVersion" = "karpenter.sh/v1"
    "kind"       = "NodePool"
    "metadata" = {
      "name" = random_id.node_pool_name.hex
    }
    "spec" = local.node_pool_spec
  })
  force_new = true
  depends_on = [
    module.eks_blueprints_addons
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "kubectl_manifest" "karpenter_node_class" {
  count = var.addons.enable_karpenter && var.addons.enable_default_karpenter_nodeclass ? 1 : 0
  yaml_body = yamlencode({
    "apiVersion" = "karpenter.k8s.aws/v1"
    "kind"       = "EC2NodeClass"
    "metadata" = {
      "name" = "default"
    }
    "spec" = {
      "amiFamily" = "AL2023"
      "amiSelectorTerms" = [
        { "alias" : "al2023@latest" }
      ]
      "kubelet" = {
        "systemReserved" : {
          "cpu"    = "100m"
          "memory" = "100Mi"
        }
        "podsPerCore" = 14
      }
      "blockDeviceMappings" = [
        {
          "deviceName" = "/dev/xvda"
          "ebs" = {
            "deleteOnTermination" = true
            "encrypted"           = true
            "volumeSize"          = "${var.docker_storage_size}Gi"
            "volumeType"          = "gp3"
          }
        },
      ]
      "role"                       = module.eks_blueprints_addons.karpenter.node_iam_role_name
      "securityGroupSelectorTerms" = [{ tags = local.karpenter_discovery }, { tags = local.karpenter_discovery_per_cluster }]
      "subnetSelectorTerms"        = [{ tags = local.karpenter_discovery }, { tags = local.karpenter_discovery_per_cluster }]
      "tags"                       = merge(var.tags, { "managedBy" = "karpenter" })
    }
  })
  depends_on = [
    module.eks_blueprints_addons
  ]
  lifecycle {
    create_before_destroy = true
  }
}
