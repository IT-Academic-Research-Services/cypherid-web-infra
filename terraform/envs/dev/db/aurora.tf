# Aurora MySQL 8.0 db cluster — canonical, mirrored across dev/staging/prod (CZID-332).
# Parameterized so it is safe in BOTH live and greenfield envs:
#   - var.db_instance_class      : the per-env machine size (the intended difference)
#   - var.manage_db_subnet_group : false on LIVE envs (dev/staging) -> reference the existing
#                                  subnet group (plan no-op, no cluster replacement);
#                                  true on greenfield envs (prod) -> create it fresh.
# dev/staging are LIVE with data: a terraform plan MUST show no destructive changes before apply.
locals {
  db_subnet_group_name = var.manage_db_subnet_group ? aws_db_subnet_group.db[0].name : "${var.project}-${var.env}"

  # CZID-351 (DATA-2): the customer-managed RDS key ARN when managed (greenfield), else null so the
  # cluster / PI / backup fall back to the AWS-managed key with NO change on live envs. Storage
  # encryption key is immutable, hence the greenfield gate (var.manage_db_kms_cmk).
  db_kms_key_arn = var.manage_db_kms_cmk ? aws_kms_key.rds[0].arn : null
}

resource "aws_rds_cluster" "db" {
  enable_http_endpoint                = true # This enables Query Editor in the AWS RDS UI
  cluster_identifier                  = "${var.project}-${var.env}"
  database_name                       = "${var.project}_${var.env}"
  master_username                     = var.db_username
  master_password                     = module.db_password.value
  vpc_security_group_ids              = [aws_security_group.rds.id]
  db_subnet_group_name                = local.db_subnet_group_name
  storage_encrypted                   = true
  kms_key_id                          = local.db_kms_key_arn # CZID-351: CMK on greenfield, AWS-managed (null) on live
  iam_database_authentication_enabled = true
  engine                              = "aurora-mysql"
  deletion_protection                 = !contains(["dev", "sandbox"], var.env)
  copy_tags_to_snapshot               = true
  backup_retention_period             = 7
  skip_final_snapshot                 = true

  # CZID-351 (DATA-2, CKV_AWS_324/325): ship cluster logs to CloudWatch + capture the audit log.
  # NOT "general" — that logs every statement (PII); audit/error/slowquery only.
  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db_8.id

  final_snapshot_identifier = "${var.project}-${var.env}-final"
}

resource "aws_rds_cluster_instance" "db" {
  count                   = 1
  identifier              = "${var.project}-${var.env}-${count.index}"
  cluster_identifier      = aws_rds_cluster.db.id
  instance_class          = var.db_instance_class
  db_subnet_group_name    = local.db_subnet_group_name
  db_parameter_group_name = aws_db_parameter_group.db_8.name
  # CZID-351 (DATA-2, CKV_AWS_118): enhanced monitoring at 60s via the monitoring role.
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  # CZID-351 (DATA-2, CKV_AWS_353/354): Performance Insights, encrypted with the CMK where managed.
  performance_insights_enabled    = true
  performance_insights_kms_key_id = local.db_kms_key_arn
  auto_minor_version_upgrade      = true
  ca_cert_identifier              = "rds-ca-ecc384-g1"
  engine                          = aws_rds_cluster.db.engine

  tags = {
    terraform = true
  }
}

resource "aws_rds_cluster_parameter_group" "db_8" {
  name   = "${var.project}-${var.env}-rds-cluster-pg-8"
  family = "aurora-mysql8.0"

  # DO NOT "improve" this string. AWS makes description IMMUTABLE, so changing it forces
  # terraform to REPLACE the parameter group -- and because the name is fixed (no
  # create_before_destroy is possible without a name_prefix), terraform destroys FIRST.
  # That destroy can never succeed while the cluster's instances are members
  # (InvalidDBParameterGroupState), so every `db` apply spent 2+ minutes retrying the
  # deletion of the LIVE database's parameter group before failing. A cosmetic string was
  # one detached instance away from deleting it for real. This value is kept EXACTLY as it
  # exists in AWS so terraform sees no diff and never attempts the replacement.
  #
  # If it ever genuinely must change: create a NEW parameter group, modify the cluster to
  # use it, reboot the instance, and only then remove the old one -- deliberately, in a
  # maintenance window. See platform-overhaul #687.
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

  # CZID-351 (DATA-2, CKV_AWS_325): enable the MariaDB Audit plugin so the cluster produces the
  # audit log that enabled_cloudwatch_logs_exports ships. Scope events to connections + privilege/
  # schema changes (CONNECT/QUERY_DCL/QUERY_DDL) — NOT full QUERY, to avoid logging data/PII.
  parameter {
    apply_method = "pending-reboot"
    name         = "server_audit_logging"
    value        = "1"
  }

  parameter {
    apply_method = "pending-reboot"
    name         = "server_audit_events"
    value        = "CONNECT,QUERY_DCL,QUERY_DDL"
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
    value = "0"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name         = "log_output"
    value        = "FILE"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  parameter {
    name  = "group_concat_max_len"
    value = "1073741824"
  }

  tags = {
    terraform = true
  }
}

# Created ONLY in greenfield envs (var.manage_db_subnet_group = true, e.g. prod).
# Live envs (dev/staging) keep their existing subnet group via local.db_subnet_group_name.
resource "aws_db_subnet_group" "db" {
  count      = var.manage_db_subnet_group ? 1 : 0
  name       = "${var.project}-${var.env}-main"
  subnet_ids = data.terraform_remote_state.cloud-env.outputs.private_subnets

  tags = {
    terraform = true
  }
}
