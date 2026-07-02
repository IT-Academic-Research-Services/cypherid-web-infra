resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-rds"
  description = "MySQL RDS"

  vpc_id = data.terraform_remote_state.cloud-env.outputs.vpc_id

  tags = {
    terraform = true
    Name      = "${var.project}-${var.env}-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_private" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow MySQL RDS inbound private traffic"

  cidr_ipv4   = data.terraform_remote_state.cloud-env.outputs.vpc_cidr_block
  from_port   = 3306
  ip_protocol = "tcp"
  to_port     = 3306
}

module "db-params" {
  source  = "../../../modules/aws-ssm-params-writer-v0.104.2" # cztack v0.104.2
  project = var.project
  env     = var.env
  service = "web"
  owner   = var.owner

  parameters = {
    DB_PORT                = aws_rds_cluster.db.port
    DB_USERNAME            = aws_rds_cluster.db.master_username
    RDS_ADDRESS_PUBLIC     = aws_rds_cluster_instance.db[0].endpoint
    RDS_ADDRESS            = aws_rds_cluster.db.endpoint
    SAMPLES_BUCKET_NAME    = aws_s3_bucket.samples.bucket
    SAMPLES_BUCKET_NAME_V1 = aws_s3_bucket.samples_v1.bucket
  }
}
