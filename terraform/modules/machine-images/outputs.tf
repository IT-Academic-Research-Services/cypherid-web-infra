# output "czi_ubuntu16_master_pinned" {
#   description = "DEPRECATED use czi_ubuntu16"
#   value       = var.czi_ubuntu16_main_pinned
# }
#
# output "czi_ubuntu18_master_pinned" {
#   description = "DEPRECATED use czi_ubuntu18"
#   value       = var.czi_ubuntu18_main_pinned
# }
#
# output "czi_ubuntu18_deep_learning_master_pinned" {
#   description = "DEPRECATED use czi_ubuntu18_deep_learning"
#   value       = var.czi_ubuntu18_deep_learning_main_pinned
# }
#
# output "czi_amazon_master_pinned" {
#   description = "DEPRECATED use czi_amazon"
#   value       = var.czi_amazon_main_pinned
# }
#
# output "czi_amazon1_master_pinned" {
#   description = "DEPRECATED use czi_amazon1"
#   value       = var.czi_amazon1_main_pinned
# }
#
# output "czi_amazon2_ecs_master_pinned" {
#   description = "DEPRECATED use czi_amazon2_ecs"
#   value       = var.czi_amazon2_ecs_main_pinned
# }
#
# output "czi_amazon2_eks_master_pinned" {
#   description = "DEPRECATED use czi_amazon2_eks"
#   value = {
#     "1.16" = var.czi_amazon2_eks_1_16_main_pinned,
#   }
# }
#
#
# # main
#
# output "czi_ubuntu16" {
#   description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
#   value       = var.czi_ubuntu16_main_pinned[data.aws_region.current.name]
# }
#
# output "czi_ubuntu18" {
#   description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
#   value       = var.czi_ubuntu18_main_pinned[data.aws_region.current.name]
# }
#
# output "czi_ubuntu18_deep_learning" {
#   description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
#   value       = var.czi_ubuntu18_deep_learning_main_pinned[data.aws_region.current.name]
# }
#
# output "czi_amazon" {
#   description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
#   value       = var.czi_amazon_main_pinned[data.aws_region.current.name]
# }
#
# output "czi_amazon1" {
#   description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
#   value       = var.czi_amazon1_main_pinned[data.aws_region.current.name]
# }

output "czi_amazon2_ecs" {
  description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
  value       = data.aws_ami.ecs_ami.image_id
}

# output "czi_amazon2_eks" {
#   description = "Stable id for a recent build. Updated explicitly to avoid unintended changes."
#   value = {
#     "1.16" = var.czi_amazon2_eks_1_16_main_pinned[data.aws_region.current.name],
#   }
# }
