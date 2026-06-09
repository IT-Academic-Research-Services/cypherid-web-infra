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

# resource "aws_vpc_security_group_ingress_rule" "rds_public" {
#   security_group_id = aws_security_group.rds.id
#   description       = "Allow MySQL RDS inbound public traffic" # TODO: From Auth0
#
#   cidr_ipv4   = "0.0.0.0/0"
#   from_port   = 3306
#   ip_protocol = "tcp"
#   to_port     = 3306
# }

# resource "aws_vpc_security_group_egress_rule" "rds" {
#   security_group_id = aws_security_group.rds.id
#   description       = "Allow MySQL RDS outbound public traffic"
#
#   cidr_ipv4   = "0.0.0.0/0"
#   ip_protocol = "-1"
# }

module "db-params" {
  source  = "github.com/chanzuckerberg/cztack//aws-ssm-params-writer?ref=v0.104.2"
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
    # NOTE: SKIP_TEST_DATABASE needs to be set, or else Rails.env.development will use the "test" DB
    # See: active_record/tasks/database_tasks.rb:551
    # https://stackoverflow.com/questions/9930361/rake-dbmigrate-and-rake-dbcreate-both-work-on-test-database-not-development-d
    SKIP_TEST_DATABASE = true
  }
}
