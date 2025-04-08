data "aws_ssm_parameter" "db_secret" {
  name = "${local.ssm_param_name}_password"
  depends_on = [
    aws_ssm_parameter.db_master_password
  ]
}

resource "aws_rds_cluster" "db" {
  cluster_identifier                  = "${var.project}-${var.env}"
  database_name                       = "${var.project}_${var.env}"
  master_username                     = var.db_username
  master_password                     = data.aws_ssm_parameter.db_secret.value
  vpc_security_group_ids              = [aws_security_group.rds.id]
  db_subnet_group_name                = aws_db_subnet_group.db.name
  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  engine                              = "aurora-mysql"

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db.id

  final_snapshot_identifier = "${var.project}-${var.env}-final"
}
//R3 and R4 have been deprecated as of 2023. Upgraded to R5.
resource "aws_rds_cluster_instance" "db" {
  count                   = 1
  identifier              = "${var.project}-${var.env}-${count.index}"
  cluster_identifier      = aws_rds_cluster.db.id
  instance_class          = "db.r5.xlarge"
  db_subnet_group_name    = aws_db_subnet_group.db.name
  db_parameter_group_name = aws_db_parameter_group.db.name
  monitoring_interval     = 0
  engine                  = aws_rds_cluster.db.engine

  tags = {
    terraform = true
    project   = var.project
    env       = var.env
  }
}

resource "aws_rds_cluster_parameter_group" "db" {
  name        = "${var.project}-${var.env}-rds-cluster-pg"
  family      = "aurora-mysql8.0"
  description = "RDS default cluster parameter group"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "binlog_format"
    value        = "ROW"
  }

  tags = {
    terraform = true
    project   = var.project
    env       = var.env
  }
}

resource "aws_db_parameter_group" "db" {
  name   = "${var.project}-${var.env}-rds-pg"
  family = "aurora-mysql8.0"

  parameter {
    name  = "general_log"
    value = "1"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "0"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  tags = {
    terraform = true
    project   = var.project
    env       = var.env
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project}-${var.env}-main"
  subnet_ids = data.terraform_remote_state.cloud-env.outputs.private_subnets

  tags = {
    terraform = true
    project   = var.project
    env       = var.env
  }
}
