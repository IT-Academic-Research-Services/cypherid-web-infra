locals {
  service     = "es"
  name        = "${var.project}-${var.env}-${local.service}"
  bucket_name = "idseq-${var.env}-heatmap-batch-jobs-941377154785" //TODO - parameterize this account ID later
  account_id  = var.aws_accounts["idseq-dev"]
  tags = {
    managedBy = "terraform"
    Name      = local.name
    project   = var.project
    env       = var.env
    service   = local.service
    owner     = var.owner
  }
}

# The security group is used by the taxon-indexing-lambda in the idseq codebase
resource "aws_security_group" "glue_sec_group" {
  name   = "${var.project}_${var.env}_glue_sec_group"
  vpc_id = data.terraform_remote_state.cloud-env.outputs.vpc_id
}

resource "aws_security_group_rule" "sec_group_allow_tcp" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.glue_sec_group.id
  source_security_group_id = aws_security_group.glue_sec_group.id
}

resource "aws_security_group_rule" "sec_group_outbound_tcp" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.glue_sec_group.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sec_group_outbound_czid" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "all"
  source_security_group_id = aws_security_group.glue_sec_group.id
  security_group_id        = aws_security_group.glue_sec_group.id
}

module "idseq-heatmap-es-param" {
  source  = "github.com/chanzuckerberg/cztack//aws-ssm-params-writer?ref=v0.43.3"
  project = var.project
  env     = var.env
  service = "web"
  owner   = var.owner

  parameters = {
    HEATMAP_ES_ADDRESS = "https://${module.elasticsearch.elasticsearch_endpoint}"
  }
}

# --------------------------------------------
# batch-taxon-indexing glue job
# --------------------------------------------

data "aws_iam_policy_document" "glue_batch_taxon_indexing_policy_doc" {
  statement {
    sid = "s3"

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = ["arn:aws:s3:::${local.bucket_name}/*"]
  }
  statement {
    sid = "Lambda"

    actions = [
      "lambda:InvokeFunction",
    ]

    resources = [
      "arn:aws:lambda:${var.region}:${local.account_id}:function:taxon-indexing-lambda-${var.env}-index_taxons"
    ]
  }
}

resource "aws_iam_policy" "glue_batch_taxon_indexing_policy" {
  name   = "${var.project}-${var.env}-batch-taxon-indexing-policy"
  policy = data.aws_iam_policy_document.glue_batch_taxon_indexing_policy_doc.json
}

resource "aws_iam_role" "glue-batch-taxon-indexing-role" {
  name               = "${var.env}_AWSGlueServiceRoleBatchTaxonIndexing"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_batch_taxon_indexing_role_policy" {
  role       = aws_iam_role.glue-batch-taxon-indexing-role.name
  policy_arn = aws_iam_policy.glue_batch_taxon_indexing_policy.arn
}

resource "aws_iam_role_policy_attachment" "glue-service-role-policy" {
  role       = aws_iam_role.glue-batch-taxon-indexing-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

module "aws-s3-batch-taxon-indexing-private-bucket" {
  source      = "github.com/chanzuckerberg/cztack//aws-s3-private-bucket?ref=v0.73.0"
  bucket_name = local.bucket_name
  env         = var.env
  owner       = var.owner
  project     = var.project
  service     = var.component
}

resource "aws_glue_job" "batch-taxon-indexing" {
  name            = "idseq-${var.env}-batch-taxon-indexing"
  description     = "Job that takes an array of taxon-indexing-lambda parameters and runs them."
  execution_class = "STANDARD"
  role_arn        = aws_iam_role.glue-batch-taxon-indexing-role.arn
  glue_version    = "3.0"
  tags            = local.tags

  command {
    name            = "pythonshell"
    script_location = "s3://${local.bucket_name}/releases/main.py"
    python_version  = 3.9
  }
  execution_property {
    max_concurrent_runs = 1
  }
  max_capacity = 0.0625
  timeout      = 2880

  default_arguments = {
    "--TempDir"              = "s3://${local.bucket_name}/temporary/"
    "--enable-job-insights"  = false
    "--extra-py-files"       = "s3://idseq-${var.env}-heatmap-batch-jobs/releases/job.py,s3://idseq-${var.env}-heatmap-batch-jobs/releases/config.py"
    "--job-language"         = "python"
    "--pip-install"          = "tenacity==8.2.2"
    "library-set"            = "analytics"
    "--lambda_function_name" = "taxon-indexing-lambda-${var.env}-index_taxons"
    "--input_s3_bucket"      = local.bucket_name
  }
}