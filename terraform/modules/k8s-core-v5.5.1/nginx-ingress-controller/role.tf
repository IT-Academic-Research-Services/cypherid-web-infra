module "eks_service_account_nginx_role" {
  source = "git@github.com:chanzuckerberg/cztack//aws-iam-service-account-eks?ref=v0.104.2"

  eks_cluster   = var.eks_cluster
  k8s_namespace = var.namespace
  tags          = var.tags
}

resource "aws_iam_role_policy" "nginx_ingress_bucket_access_attach" {
  name_prefix = "nginx-ingress-maxmind-read-access-"
  role        = module.eks_service_account_nginx_role.iam_role
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::argus-maxminddb",
          "arn:aws:s3:::argus-maxminddb/*"
        ]
      }
    ]
  })
}