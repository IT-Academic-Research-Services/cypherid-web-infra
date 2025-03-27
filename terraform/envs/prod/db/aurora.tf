resource "aws_rds_cluster" "db" {
  cluster_identifier                  = "${var.project}-${var.env}"
  database_name                       = "${var.project}_${var.env}"
  master_username                     = var.db_username
  master_password                     = module.db_password.value
  vpc_security_group_ids              = [aws_security_group.rds.id]
  db_subnet_group_name                = aws_db_subnet_group.db.name
  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  backup_retention_period             = 7
  engine                              = "aurora-mysql"

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db.id

  final_snapshot_identifier = "${var.project}-${var.env}-final"

  engine_mode = "provisioned"

}

resource "aws_rds_cluster_instance" "db" {
  count               = 1
  identifier          = "${var.project}-${var.env}-${count.index}"
  cluster_identifier  = aws_rds_cluster.db.id
  monitoring_interval = 0

  # In January 2018 US-West-2
  # r4.4xlarge = 8 physical CPU cores, 122 GiB RAM, ** 437 MB/sec EBS bw **
  # r4.2xlarge = 4 physical CPU cores,  61 GiB RAM, ** 213 MB/sec EBS bw **
  instance_class = "db.r4.4xlarge"

  db_subnet_group_name    = aws_db_subnet_group.db.name
  db_parameter_group_name = aws_db_parameter_group.db.name
  ca_cert_identifier      = "rds-ca-ecc384-g1"
  engine                  = aws_rds_cluster.db.engine

  tags = {
    terraform = true
    project   = var.project
    env       = var.env
  }
}

resource "aws_rds_cluster_parameter_group" "db" {
  name        = "${var.project}-${var.env}-rds-cluster-pg"
  family      = "aurora-mysql5.7"
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
    value        = "row"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "max_allowed_packet"
    value        = 1073741824
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "performance_schema"
    value        = 1
  }

  parameter {
    apply_method = "immediate"
    name         = "group_concat_max_len"
    value        = "1048576"
  }

  tags = {
    terraform = true
    project   = var.project
    env       = var.env
  }
}

resource "aws_db_parameter_group" "db" {
  name   = "${var.project}-${var.env}-rds-pg"
  family = "aurora-mysql5.7"

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
    value = "file"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  parameter {
    name  = "group_concat_max_len"
    value = "1073741824"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "performance_schema"
    value        = "1"
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
