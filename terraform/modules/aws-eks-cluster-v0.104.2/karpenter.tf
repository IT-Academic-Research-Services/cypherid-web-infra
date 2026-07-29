locals {
  node_pool_spec = {
    "disruption" = {
      "consolidationPolicy" = "WhenEmptyOrUnderutilized"
      "consolidateAfter"    = "24h"
    }

    "template" = {
      "spec" = {
        "terminationGracePeriod" = "1h"
        "expireAfter"            = "${15 * 24}h"

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
          # restrictions against a1 instances. Also, NLBs are not allowed to use the following
          # instance families in target groups if using target type instance.
          # https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/3508
          {
            "key"      = "karpenter.k8s.aws/instance-family"
            "operator" = "NotIn"
            "values" = [
              "a1",
              "c1",
              "cc1",
              "cc2",
              "cg1",
              "cg2",
              "cr1",
              "g1",
              "g2",
              "hi1",
              "hs1",
              "m1",
              "m2",
              "m3",
              "t1",
            ]
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
    module.karpenter_controller
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
      # Kubelet resource management. The previous config (systemReserved 100m/100Mi,
      # no kubeReserved, podsPerCore 14) left the kubelet with no protected CPU/memory:
      # under load, application pods saturated small nodes to ~100% CPU and >100% memory,
      # the kubelet missed its node-status heartbeats, and nodes flapped NotReady
      # ("Kubelet stopped posting node status") in an endless die/recover cycle. Reserve a
      # real slice for the kubelet + system daemons and add eviction thresholds so the node
      # sheds pods before it takes itself down. podsPerCore lowered so nodes are not
      # oversubscribed (14 permitted 28 pods on a 2-vCPU node). See platform-overhaul #699.
      "kubelet" = {
        "kubeReserved" = {
          "cpu"    = "250m"
          "memory" = "600Mi"
        }
        "systemReserved" = {
          "cpu"    = "250m"
          "memory" = "300Mi"
        }
        "evictionHard" = {
          "memory.available"  = "200Mi"
          "nodefs.available"  = "10%"
          "imagefs.available" = "10%"
        }
        "podsPerCore" = 8
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
      "role"                       = aws_iam_role.karpenter_node.name
      "securityGroupSelectorTerms" = [{ tags = local.karpenter_discovery }, { tags = local.karpenter_discovery_per_cluster }]
      "subnetSelectorTerms"        = [{ tags = local.karpenter_discovery }, { tags = local.karpenter_discovery_per_cluster }]
      "tags"                       = merge(var.tags, { "managedBy" = "karpenter" })
    }
  })
  depends_on = [
    module.karpenter_controller
  ]
  lifecycle {
    create_before_destroy = true
  }
}
