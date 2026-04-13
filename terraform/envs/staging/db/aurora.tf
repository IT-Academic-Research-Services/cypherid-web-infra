resource "aws_rds_cluster" "db" {
  enable_http_endpoint                = true # This enables Query Editor in the AWS RDS UI
  cluster_identifier                  = "${var.project}-${var.env}"
  database_name                       = "${var.project}_${var.env}"
  master_username                     = var.db_username
  master_password                     = module.db_password.value
  vpc_security_group_ids              = [aws_security_group.rds.id]
  db_subnet_group_name                = aws_db_subnet_group.db.name
  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  engine                              = "aurora-mysql"

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db_8.id

  final_snapshot_identifier = "${var.project}-${var.env}-final"
}

resource "aws_rds_cluster_instance" "db" {
  count                   = 1
  identifier              = "${var.project}-${var.env}-${count.index}"
  cluster_identifier      = aws_rds_cluster.db.id
  instance_class          = "db.r5.xlarge"
  db_subnet_group_name    = aws_db_subnet_group.db.name
  db_parameter_group_name = aws_db_parameter_group.db_8.name
  monitoring_interval     = 0
  ca_cert_identifier      = "rds-ca-ecc384-g1"
  engine                  = aws_rds_cluster.db.engine

  tags = {
    terraform = true
  }
}

resource "aws_rds_cluster_parameter_group" "db_8" {
  name        = "${var.project}-${var.env}-rds-cluster-pg-8"
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
  }
}

resource "aws_db_parameter_group" "db_8" {
  name   = "${var.project}-${var.env}-rds-pg-8"
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
    apply_method = "pending-reboot"
    name         = "log_output"
    value        = "FILE"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  # TODO: This got removed for some reason sometime April-December 2025; Re-added Feb 2026
  parameter {
    name  = "group_concat_max_len"
    value = "1073741824"
  }

  tags = {
    terraform = true
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project}-${var.env}-main"
  subnet_ids = data.terraform_remote_state.cloud-env.outputs.private_subnets

  tags = {
    terraform = true
  }
}
