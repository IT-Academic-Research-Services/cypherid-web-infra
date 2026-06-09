variable "architecture" {
  type    = string
  default = "x86_64"
}

# TODO: Rerun update-pinned.sh to make this more stable
# variable "czi_ubuntu16_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-09b7a0117e7334299"
#     us-east-2 = "ami-0478c4ec545eb8352"
#     us-west-1 = "ami-032b97d7e8a2bf5c6"
#     us-west-2 = "ami-0913acde05acb8c17"
#   }
# }
#
# variable "czi_ubuntu18_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-063d83ca61822e612"
#     us-east-2 = "ami-0c73e054a8b3c67ed"
#     us-west-1 = "ami-0bb8948bde2c55c78"
#     us-west-2 = "ami-0700d9eac1644d072"
#   }
# }
#
# variable "czi_amazon_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-0ad0e76963afe60a6"
#     us-east-2 = "ami-059e0242bdfed18df"
#     us-west-1 = "ami-017543474bfaceeb8"
#     us-west-2 = "ami-040551199f0489d9e"
#   }
# }
#
# variable "czi_amazon2_ecs_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-0633be66ac3513330"
#     us-east-2 = "ami-07d774cc9e2eb313f"
#     us-west-1 = "ami-04e07f1ce2e9d3d89"
#     us-west-2 = "ami-087a41a5f3f4ead9b"
#   }
# }
#
# variable "czi_amazon2_eks_1_16_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-0c0820a8fdbe016c7"
#     us-east-2 = "ami-03a8bac5da6aa6d3c"
#     us-west-1 = "ami-0858fd30f8de868bd"
#     us-west-2 = "ami-0115cdede08a9f812"
#   }
# }
#
# variable "czi_ubuntu18_deep_learning_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-0ea85151d89f43777"
#     us-east-2 = "ami-0c2155cd2efb47dff"
#     us-west-1 = "ami-007de35fa390e1398"
#     us-west-2 = "ami-0fc3116e791be3497"
#   }
# }
#
# variable "czi_amazon1_main_pinned" {
#   type = map(string)
#
#   default = {
#     us-east-1 = "ami-0fc5781d1d520711c"
#     us-east-2 = "ami-0a44c06a5a8cab8e0"
#     us-west-1 = "ami-0bf98f52cab7f2d37"
#     us-west-2 = "ami-0aafe3dafd1634e7e"
#   }
# }
